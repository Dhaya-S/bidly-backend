package com.bidly.community.service;

import com.bidly.common.exception.BidlyException;
import com.bidly.community.dto.AddMemberRequest;
import com.bidly.community.dto.CommunityDto;
import com.bidly.community.dto.CommunityMemberDto;
import com.bidly.community.dto.CreateCommunityRequest;
import com.bidly.community.entity.Community;
import com.bidly.community.entity.CommunityMember;
import com.bidly.community.repository.CommunityMemberRepository;
import com.bidly.community.repository.CommunityRepository;
import com.bidly.user.entity.User;
import com.bidly.user.repository.UserRepository;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.Instant;
import java.util.*;
import java.util.stream.Collectors;

@Service
public class CommunityService {

    private static final Logger log = LoggerFactory.getLogger(CommunityService.class);

    private final CommunityRepository communityRepository;
    private final CommunityMemberRepository memberRepository;
    private final UserRepository userRepository;

    public CommunityService(
            CommunityRepository communityRepository,
            CommunityMemberRepository memberRepository,
            UserRepository userRepository) {
        this.communityRepository = communityRepository;
        this.memberRepository = memberRepository;
        this.userRepository = userRepository;
    }

    /**
     * Get all active communities with membership and unread metrics for the user.
     */
    public List<CommunityDto> getCommunities(UUID userId, String search) {
        List<Community> communities = communityRepository.findByActiveTrueOrderByCreatedAtDesc();

        if (search != null && !search.isBlank()) {
            String query = search.trim().toLowerCase();
            communities = communities.stream()
                    .filter(c -> c.getName().toLowerCase().contains(query)
                            || (c.getDescription() != null && c.getDescription().toLowerCase().contains(query))
                            || (c.getCategory() != null && c.getCategory().toLowerCase().contains(query)))
                    .collect(Collectors.toList());
        }

        Map<UUID, String> userRoles = new HashMap<>();
        if (userId != null) {
            memberRepository.findByUserId(userId).forEach(m -> userRoles.put(m.getCommunityId(), m.getRole()));
        }

        return communities.stream()
                .map(c -> {
                    String role = userRoles.get(c.getId());
                    if (role == null && c.getCreatedBy() != null && userId != null && c.getCreatedBy().equals(userId)) {
                        role = "ADMIN";
                    }
                    return mapToDto(c, role);
                })
                .collect(Collectors.toList());
    }

    /**
     * Create a new community and assign current user as ADMIN.
     */
    @Transactional
    public CommunityDto createCommunity(UUID userId, CreateCommunityRequest request) {
        if (userId == null) {
            throw BidlyException.unauthorized("Authentication required to create community");
        }

        Community community = new Community();
        community.setName(request.getName().trim());
        community.setDescription(request.getDescription() != null ? request.getDescription().trim() : null);
        community.setCategory(request.getCategory() != null ? request.getCategory() : "Other");
        community.setAddress(request.getAddress());
        community.setLatitude(request.getLatitude());
        community.setLongitude(request.getLongitude());
        community.setRadiusKm(request.getRadiusKm() > 0 ? request.getRadiusKm() : 5);
        community.setRules(request.getRules());
        community.setIconUrl(request.getIconUrl());
        community.setBannerUrl(request.getBannerUrl());
        community.setCreatedBy(userId);
        community.setMembersCount(1);
        community.setActive(true);
        community.setRecentActivityText("Community created. Welcome!");
        community.setRecentActivityTime(Instant.now());

        Community saved = communityRepository.save(community);

        // Add creator as ADMIN in community_members
        CommunityMember adminMember = new CommunityMember(saved.getId(), userId, "ADMIN");
        memberRepository.save(adminMember);

        log.info("Created community '{}' ({}) by admin user {}", saved.getName(), saved.getId(), userId);

        return mapToDto(saved, "ADMIN");
    }

    /**
     * Get single community details.
     */
    public CommunityDto getCommunity(UUID communityId, UUID userId) {
        Community community = communityRepository.findById(communityId)
                .orElseThrow(() -> BidlyException.notFound("Community"));

        String role = null;
        if (userId != null) {
            role = memberRepository.findByCommunityIdAndUserId(communityId, userId)
                    .map(CommunityMember::getRole)
                    .orElse(null);
            if (role == null && community.getCreatedBy() != null && community.getCreatedBy().equals(userId)) {
                role = "ADMIN";
            }
        }

        return mapToDto(community, role);
    }

    /**
     * List members of a community.
     */
    public List<CommunityMemberDto> getMembers(UUID communityId) {
        Community community = communityRepository.findById(communityId).orElse(null);
        List<CommunityMember> members = memberRepository.findByCommunityId(communityId);

        // Ensure creator is present as ADMIN in members if not already recorded
        if (community != null && community.getCreatedBy() != null) {
            boolean hasCreator = members.stream().anyMatch(m -> m.getUserId().equals(community.getCreatedBy()));
            if (!hasCreator) {
                CommunityMember creatorMember = new CommunityMember(communityId, community.getCreatedBy(), "ADMIN");
                try {
                    memberRepository.save(creatorMember);
                } catch (Exception ignored) {}
                members.add(creatorMember);
            }
        }

        List<UUID> userIds = members.stream().map(CommunityMember::getUserId).collect(Collectors.toList());
        Map<UUID, User> userMap = userRepository.findAllById(userIds).stream()
                .collect(Collectors.toMap(User::getId, u -> u));

        return members.stream().map(m -> {
            User u = userMap.get(m.getUserId());
            String name = (u != null && u.getName() != null && !u.getName().isBlank())
                    ? u.getName().trim()
                    : (u != null && u.getPhone() != null && !u.getPhone().isBlank() ? "User " + u.getPhone() : "Bidly Member");
            String phone = u != null ? u.getPhone() : "";
            String avatar = u != null ? u.getAvatarUrl() : null;
            return new CommunityMemberDto(m.getUserId(), name, phone, avatar, m.getRole(), m.getJoinedAt());
        }).collect(Collectors.toList());
    }

    /**
     * Admin adds a member to community by phone number or user ID.
     */
    @Transactional
    public CommunityMemberDto addMember(UUID communityId, UUID adminUserId, AddMemberRequest request) {
        Community community = communityRepository.findById(communityId)
                .orElseThrow(() -> BidlyException.notFound("Community"));

        // Verify Admin permission
        boolean isAdmin = memberRepository.existsByCommunityIdAndUserIdAndRole(communityId, adminUserId, "ADMIN")
                || (community.getCreatedBy() != null && community.getCreatedBy().equals(adminUserId));
        if (!isAdmin) {
            throw BidlyException.unauthorized("Only community admins can add members");
        }

        User targetUser = null;
        if (request.getUserId() != null) {
            targetUser = userRepository.findById(request.getUserId()).orElse(null);
        } else if (request.getPhone() != null && !request.getPhone().isBlank()) {
            String cleanPhone = request.getPhone().replaceAll("\\D", "");
            targetUser = userRepository.findByPhone(cleanPhone).orElse(null);
            if (targetUser == null) {
                targetUser = new User();
                targetUser.setPhone(cleanPhone);
                targetUser.setName("Member " + cleanPhone.substring(Math.max(0, cleanPhone.length() - 4)));
                targetUser.setActive(true);
                targetUser = userRepository.save(targetUser);
            }
        }

        if (targetUser == null) {
            throw BidlyException.badRequest("Please provide a valid user phone number or ID");
        }

        if (memberRepository.existsByCommunityIdAndUserId(communityId, targetUser.getId())) {
            throw BidlyException.conflict("User is already a member of this community");
        }

        String role = request.getRole() != null && request.getRole().equalsIgnoreCase("ADMIN") ? "ADMIN" : "MEMBER";
        CommunityMember member = new CommunityMember(communityId, targetUser.getId(), role);
        CommunityMember saved = memberRepository.save(member);

        // Increment member count
        community.setMembersCount(community.getMembersCount() + 1);
        communityRepository.save(community);

        log.info("Admin {} added user {} as {} to community {}", adminUserId, targetUser.getId(), role, communityId);

        return new CommunityMemberDto(
                targetUser.getId(),
                targetUser.getName(),
                targetUser.getPhone(),
                targetUser.getAvatarUrl(),
                saved.getRole(),
                saved.getJoinedAt()
        );
    }

    /**
     * Admin removes a member, or member leaves community.
     */
    @Transactional
    public void removeMember(UUID communityId, UUID requesterUserId, UUID targetUserId) {
        Community community = communityRepository.findById(communityId)
                .orElseThrow(() -> BidlyException.notFound("Community"));

        boolean isAdmin = memberRepository.existsByCommunityIdAndUserIdAndRole(communityId, requesterUserId, "ADMIN")
                || (community.getCreatedBy() != null && community.getCreatedBy().equals(requesterUserId));

        // Allowed if requester is Admin OR user is removing themselves
        if (!isAdmin && !requesterUserId.equals(targetUserId)) {
            throw BidlyException.unauthorized("Only community admins can remove members");
        }

        memberRepository.deleteByCommunityIdAndUserId(communityId, targetUserId);

        // Update count
        int updatedCount = Math.max(1, (int) memberRepository.countByCommunityId(communityId));
        community.setMembersCount(updatedCount);
        communityRepository.save(community);

        log.info("Removed member {} from community {} by requester {}", targetUserId, communityId, requesterUserId);
    }

    /**
     * Join a community as standard member.
     */
    @Transactional
    public void joinCommunity(UUID communityId, UUID userId) {
        Community community = communityRepository.findById(communityId)
                .orElseThrow(() -> BidlyException.notFound("Community"));

        if (!memberRepository.existsByCommunityIdAndUserId(communityId, userId)) {
            CommunityMember member = new CommunityMember(communityId, userId, "MEMBER");
            memberRepository.save(member);
            community.setMembersCount(community.getMembersCount() + 1);
            communityRepository.save(community);
        }
    }

    /**
     * Update community details (admin only).
     */
    @Transactional
    public CommunityDto updateCommunity(UUID communityId, UUID userId, CreateCommunityRequest request) {
        Community community = communityRepository.findById(communityId)
                .orElseThrow(() -> BidlyException.notFound("Community"));

        boolean isAdmin = memberRepository.existsByCommunityIdAndUserIdAndRole(communityId, userId, "ADMIN")
                || (community.getCreatedBy() != null && community.getCreatedBy().equals(userId));
        if (!isAdmin) {
            throw BidlyException.unauthorized("Only community admins can edit community details");
        }

        if (request.getName() != null && !request.getName().isBlank()) {
            community.setName(request.getName().trim());
        }
        if (request.getDescription() != null) {
            community.setDescription(request.getDescription().trim());
        }
        if (request.getRules() != null) {
            community.setRules(request.getRules().trim());
        }
        if (request.getCategory() != null) {
            community.setCategory(request.getCategory().trim());
        }

        Community saved = communityRepository.save(community);
        return mapToDto(saved, "ADMIN");
    }

    private CommunityDto mapToDto(Community c, String userRole) {
        CommunityDto dto = new CommunityDto();
        dto.setId(c.getId());
        dto.setName(c.getName());
        dto.setDescription(c.getDescription());
        dto.setIconUrl(c.getIconUrl());
        dto.setBannerUrl(c.getBannerUrl());
        dto.setType(c.getType());
        dto.setCategory(c.getCategory() != null ? c.getCategory() : "Other");
        dto.setCity(c.getCity());
        dto.setState(c.getState());
        dto.setAddress(c.getAddress());
        dto.setRadiusKm(c.getRadiusKm());
        dto.setRules(c.getRules());
        dto.setCreatedBy(c.getCreatedBy());
        dto.setMembersCount(c.getMembersCount());
        dto.setRecentActivityText(c.getRecentActivityText() != null ? c.getRecentActivityText() : "Active discussions & auctions");
        dto.setRecentActivityTime(c.getRecentActivityTime() != null ? c.getRecentActivityTime() : c.getCreatedAt());
        dto.setUserRole(userRole);
        dto.setAdmin("ADMIN".equalsIgnoreCase(userRole));
        dto.setJoined(userRole != null);

        // Default badge counts for seed data
        if ("IIT Madras Campus Buy & Sell".equals(c.getName())) dto.setUnreadCount(3);
        else if ("Photography Enthusiasts".equals(c.getName())) dto.setUnreadCount(1);
        else dto.setUnreadCount(0);

        return dto;
    }
}
