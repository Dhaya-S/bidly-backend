package com.bidly.community.service;

import com.bidly.common.exception.BidlyException;
import com.bidly.community.dto.CommunityDto;
import com.bidly.community.dto.CreatePostRequest;
import com.bidly.community.dto.PostDto;
import com.bidly.community.entity.Community;
import com.bidly.community.entity.CommunityPost;
import com.bidly.community.entity.PostLike;
import com.bidly.community.repository.CommunityMemberRepository;
import com.bidly.community.repository.CommunityPostRepository;
import com.bidly.community.repository.CommunityRepository;
import com.bidly.community.repository.PostLikeRepository;
import com.bidly.user.entity.User;
import com.bidly.user.repository.UserRepository;
import jakarta.annotation.PostConstruct;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageRequest;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import com.bidly.listing.dto.ListingSummaryDto;
import com.bidly.listing.entity.ListingMedia;
import java.util.Collections;
import java.util.Comparator;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.UUID;
import java.util.stream.Collectors;

@Service
public class CommunityPostService {

    private static final Logger log = LoggerFactory.getLogger(CommunityPostService.class);

    private final CommunityPostRepository postRepository;
    private final CommunityRepository communityRepository;
    private final CommunityMemberRepository memberRepository;
    private final PostLikeRepository postLikeRepository;
    private final UserRepository userRepository;
    private final com.bidly.media.service.MediaService mediaService;

    public CommunityPostService(
            CommunityPostRepository postRepository,
            CommunityRepository communityRepository,
            CommunityMemberRepository memberRepository,
            PostLikeRepository postLikeRepository,
            UserRepository userRepository,
            com.bidly.media.service.MediaService mediaService) {
        this.postRepository = postRepository;
        this.communityRepository = communityRepository;
        this.memberRepository = memberRepository;
        this.postLikeRepository = postLikeRepository;
        this.userRepository = userRepository;
        this.mediaService = mediaService;
    }

    // No dummy seed data — Real-time user data only

    /**
     * Retrieves global posts for the home feed (excludes community-specific posts).
     */
    @Transactional(readOnly = true)
    public List<PostDto> getFeed(UUID currentUserId, int page, int size) {
        long t0 = System.currentTimeMillis();
        Page<CommunityPost> postsPage = postRepository.findByCommunityIsNullOrderByCreatedAtDesc(PageRequest.of(page, size));
        long t1 = System.currentTimeMillis();

        List<CommunityPost> content = postsPage.getContent();
        Set<UUID> likedPostIds = Collections.emptySet();
        if (currentUserId != null && !content.isEmpty()) {
            List<UUID> postIds = content.stream().map(CommunityPost::getId).collect(Collectors.toList());
            likedPostIds = postLikeRepository.findLikedPostIdsByUserIdAndPostIds(currentUserId, postIds);
        }

        final Set<UUID> finalLikedIds = likedPostIds;
        List<PostDto> results = content.stream()
                .map(post -> mapToDto(post, currentUserId, finalLikedIds))
                .collect(Collectors.toList());
        long t2 = System.currentTimeMillis();
        log.info("[POST_API] page={} size={} db_ms={} mapping_ms={} total_ms={} count={}",
                page, size, (t1 - t0), (t2 - t1), (t2 - t0), results.size());
        return results;
    }

    /**
     * Retrieves posts for a specific community.
     */
    @Transactional(readOnly = true)
    public List<PostDto> getCommunityPosts(UUID communityId, UUID currentUserId, int page, int size) {
        long t0 = System.currentTimeMillis();
        Page<CommunityPost> postsPage = postRepository.findByCommunityIdOrderByCreatedAtDesc(communityId, PageRequest.of(page, size));
        long t1 = System.currentTimeMillis();

        List<CommunityPost> content = postsPage.getContent();
        Set<UUID> likedPostIds = Collections.emptySet();
        if (currentUserId != null && !content.isEmpty()) {
            List<UUID> postIds = content.stream().map(CommunityPost::getId).collect(Collectors.toList());
            likedPostIds = postLikeRepository.findLikedPostIdsByUserIdAndPostIds(currentUserId, postIds);
        }

        final Set<UUID> finalLikedIds = likedPostIds;
        List<PostDto> results = content.stream()
                .map(post -> mapToDto(post, currentUserId, finalLikedIds))
                .collect(Collectors.toList());
        long t2 = System.currentTimeMillis();
        log.info("[COMMUNITY_POST_API] communityId={} page={} size={} db_ms={} mapping_ms={} total_ms={} count={}",
                communityId, page, size, (t1 - t0), (t2 - t1), (t2 - t0), results.size());
        return results;
    }

    /**
     * Creates a new post in the feed.
     */
    @Transactional
    public PostDto createPost(UUID authorId, CreatePostRequest request) {
        if (authorId == null) {
            throw BidlyException.unauthorized("Authentication required to create a post");
        }

        User author = userRepository.findById(authorId)
                .orElseThrow(() -> BidlyException.notFound("User"));

        Community community = null;
        if (request.getCommunityId() != null) {
            community = communityRepository.findById(request.getCommunityId())
                    .orElseThrow(() -> BidlyException.notFound("Community"));

            boolean isCreator = community.getCreatedBy() != null && community.getCreatedBy().equals(authorId);
            boolean isAdmin = memberRepository.existsByCommunityIdAndUserIdAndRole(community.getId(), authorId, "ADMIN");

            if (!isCreator && !isAdmin) {
                throw BidlyException.unauthorized("Only community creator and admins can publish posts in this community");
            }
        }

        CommunityPost post = new CommunityPost();
        post.setAuthor(author);
        post.setCommunity(community);
        post.setContent(request.getContent().trim());
        post.setMediaUrl(request.getMediaUrl() != null ? request.getMediaUrl().replaceAll("\\s+", "") : null);
        post.setMediaType(request.getMediaType() != null ? request.getMediaType() : "IMAGE");
        post.setTag(request.getTag() != null ? request.getTag() : "SELLING");
        post.setLikesCount(0);
        post.setSharesCount(0);

        CommunityPost saved = postRepository.save(post);
        log.info("Created post {} by user {}", saved.getId(), authorId);

        return mapToDto(saved, authorId, Collections.emptySet());
    }

    /**
     * Toggles or ensures like/unlike on a post with idempotency and transaction safety.
     */
    @Transactional
    public Map<String, Object> toggleLike(UUID userId, UUID postId, String action) {
        if (userId == null) {
            throw BidlyException.unauthorized("Authentication required to like a post");
        }
        CommunityPost post = postRepository.findById(postId)
                .orElseThrow(() -> BidlyException.notFound("Post not found: " + postId));

        boolean alreadyLiked = postLikeRepository.existsByUserIdAndPostId(userId, postId);
        Boolean desiredLiked = null;
        if ("like".equalsIgnoreCase(action)) {
            desiredLiked = true;
        } else if ("unlike".equalsIgnoreCase(action)) {
            desiredLiked = false;
        }

        int currentCount = post.getLikesCount();
        int newCount = currentCount;

        if (desiredLiked != null) {
            if (desiredLiked && !alreadyLiked) {
                postLikeRepository.save(new PostLike(userId, postId));
                newCount = currentCount + 1;
                post.setLikesCount(newCount);
                postRepository.saveAndFlush(post);
            } else if (!desiredLiked && alreadyLiked) {
                postLikeRepository.deleteByUserIdAndPostId(userId, postId);
                newCount = Math.max(0, currentCount - 1);
                post.setLikesCount(newCount);
                postRepository.saveAndFlush(post);
            }
        } else {
            if (alreadyLiked) {
                postLikeRepository.deleteByUserIdAndPostId(userId, postId);
                newCount = Math.max(0, currentCount - 1);
                post.setLikesCount(newCount);
                postRepository.saveAndFlush(post);
            } else {
                postLikeRepository.save(new PostLike(userId, postId));
                newCount = currentCount + 1;
                post.setLikesCount(newCount);
                postRepository.saveAndFlush(post);
            }
        }

        boolean finalLiked = postLikeRepository.existsByUserIdAndPostId(userId, postId);
        log.info("[LIKE_POST] post={} action={} finalLiked={} count={}", postId, action, finalLiked, newCount);

        return Map.of(
                "liked", finalLiked,
                "likedByMe", finalLiked,
                "isLikedByMe", finalLiked,
                "likesCount", newCount
        );
    }

    @Transactional
    public boolean toggleLike(UUID userId, UUID postId) {
        Map<String, Object> res = toggleLike(userId, postId, null);
        return (Boolean) res.get("liked");
    }

    /**
     * Increments share count for a post.
     */
    @Transactional
    public int sharePost(UUID postId) {
        postRepository.incrementShares(postId);
        return postRepository.findById(postId).map(CommunityPost::getSharesCount).orElse(0);
    }

    /**
     * Lists active communities.
     */
    @Transactional(readOnly = true)
    public List<CommunityDto> getCommunities(int page, int size) {
        return communityRepository.findByActiveTrue(PageRequest.of(page, size))
                .getContent().stream()
                .map(this::mapCommunityToDto)
                .collect(Collectors.toList());
    }

    private PostDto mapToDto(CommunityPost post, UUID currentUserId, Set<UUID> likedPostIds) {
        PostDto dto = new PostDto();
        dto.setId(post.getId());
        if (post.getAuthor() != null) {
            dto.setAuthorId(post.getAuthor().getId());
            dto.setAuthorName(post.getAuthor().getName());
            String av = post.getAuthor().getAvatarUrl();
            if (av != null && !av.isBlank()) {
                String directAv = mediaService.generatePresignedGetUrl(av, java.time.Duration.ofHours(4));
                dto.setAuthorAvatarUrl(directAv != null ? directAv : av);
            }
        }
        if (post.getCommunity() != null) {
            dto.setCommunityId(post.getCommunity().getId());
            dto.setCommunityName(post.getCommunity().getName());
        }
        dto.setContent(post.getContent());
        dto.setTag(post.getTag());
        dto.setLikesCount(post.getLikesCount());
        dto.setSharesCount(post.getSharesCount());
        dto.setCreatedAt(post.getCreatedAt());

        if (post.getListing() != null) {
            com.bidly.listing.entity.Listing l = post.getListing();
            dto.setListingId(l.getId());
            dto.setSellingMethod(l.getSellingMethod() != null ? l.getSellingMethod().name() : "DIRECT_BUY");
            dto.setPrice(l.getPrice());
            dto.setStartingBid(l.getStartingBid());
            dto.setCurrentBid(l.getCurrentBid());
            dto.setAuctionEndTime(l.getAuctionEndTime());
            dto.setBidsCount(l.getBidsCount());

            if (l.getMedia() != null && !l.getMedia().isEmpty()) {
                List<ListingSummaryDto.MediaItemDto> items = l.getMedia().stream()
                        .sorted(Comparator.comparingInt(ListingMedia::getSortOrder))
                        .map(m -> {
                            String direct = mediaService.generatePresignedGetUrl(m.getUrl(), java.time.Duration.ofHours(4));
                            return new ListingSummaryDto.MediaItemDto(
                                    direct != null ? direct : m.getUrl(),
                                    m.getType() != null ? m.getType().name() : "IMAGE",
                                    m.getSortOrder()
                            );
                        })
                        .collect(Collectors.toList());
                dto.setMediaItems(items);
                dto.setMediaUrl(!items.isEmpty() ? items.get(0).getUrl() : null);
                dto.setMediaType(!items.isEmpty() ? items.get(0).getType() : "IMAGE");
            } else if (l.getPrimaryImageUrl() != null && !l.getPrimaryImageUrl().isBlank()) {
                String direct = mediaService.generatePresignedGetUrl(l.getPrimaryImageUrl(), java.time.Duration.ofHours(4));
                String finalUrl = direct != null ? direct : l.getPrimaryImageUrl();
                dto.setMediaUrl(finalUrl);
                dto.setMediaType("IMAGE");
                dto.setMediaItems(List.of(new ListingSummaryDto.MediaItemDto(finalUrl, "IMAGE", 0)));
            } else {
                dto.setMediaUrl(null);
                dto.setMediaType("IMAGE");
                dto.setMediaItems(Collections.emptyList());
            }
        } else if (post.getMediaUrl() != null && !post.getMediaUrl().isBlank()) {
            String raw = post.getMediaUrl().replaceAll("\\s+", "");
            String direct = mediaService.generatePresignedGetUrl(raw, java.time.Duration.ofHours(4));
            String finalUrl = direct != null ? direct : raw;
            dto.setMediaUrl(finalUrl);
            dto.setMediaType(post.getMediaType() != null ? post.getMediaType() : "IMAGE");
            dto.setMediaItems(List.of(new ListingSummaryDto.MediaItemDto(finalUrl, dto.getMediaType(), 0)));
        } else {
            dto.setMediaUrl(null);
            dto.setMediaType("IMAGE");
            dto.setMediaItems(Collections.emptyList());
        }

        if (likedPostIds != null && !likedPostIds.isEmpty()) {
            dto.setLikedByMe(likedPostIds.contains(post.getId()));
        } else if (currentUserId != null && likedPostIds == null) {
            dto.setLikedByMe(postLikeRepository.existsByUserIdAndPostId(currentUserId, post.getId()));
        } else {
            dto.setLikedByMe(false);
        }

        return dto;
    }

    private CommunityDto mapCommunityToDto(Community community) {
        CommunityDto dto = new CommunityDto();
        dto.setId(community.getId());
        dto.setName(community.getName());
        dto.setDescription(community.getDescription());
        dto.setIconUrl(community.getIconUrl());
        dto.setBannerUrl(community.getBannerUrl());
        dto.setType(community.getType());
        dto.setCity(community.getCity());
        dto.setState(community.getState());
        dto.setMembersCount(community.getMembersCount());
        return dto;
    }

    // No hardcoded seed data in code - only real user-created posts

}
