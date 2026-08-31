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
        Page<CommunityPost> postsPage = postRepository.findByCommunityIsNullOrderByCreatedAtDesc(PageRequest.of(page, size));
        return postsPage.getContent().stream()
                .map(post -> mapToDto(post, currentUserId))
                .collect(Collectors.toList());
    }

    /**
     * Retrieves posts for a specific community.
     */
    @Transactional(readOnly = true)
    public List<PostDto> getCommunityPosts(UUID communityId, UUID currentUserId, int page, int size) {
        Page<CommunityPost> postsPage = postRepository.findByCommunityIdOrderByCreatedAtDesc(communityId, PageRequest.of(page, size));
        return postsPage.getContent().stream()
                .map(post -> mapToDto(post, currentUserId))
                .collect(Collectors.toList());
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

        return mapToDto(saved, authorId);
    }

    /**
     * Toggles like/unlike on a post.
     */
    @Transactional
    public boolean toggleLike(UUID userId, UUID postId) {
        if (!postRepository.existsById(postId)) {
            throw BidlyException.notFound("Post");
        }

        boolean alreadyLiked = postLikeRepository.existsByUserIdAndPostId(userId, postId);
        if (alreadyLiked) {
            postLikeRepository.deleteByUserIdAndPostId(userId, postId);
            postRepository.decrementLikes(postId);
            return false;
        } else {
            postLikeRepository.save(new PostLike(userId, postId));
            postRepository.incrementLikes(postId);
            return true;
        }
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

    private PostDto mapToDto(CommunityPost post, UUID currentUserId) {
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

        if (currentUserId != null) {
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
