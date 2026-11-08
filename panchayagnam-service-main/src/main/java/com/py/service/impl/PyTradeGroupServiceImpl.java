package com.py.service.impl;

import com.py.common.dto.ApiResponse;
import com.py.common.dto.BrokerRmsDto;
import com.py.dto.PyTradeGroupMemberResponseDto;
import com.py.dto.PyTradeGroupRequestDto;
import com.py.dto.PyTradeGroupResponseDto;
import com.py.demataccount.entity.PyBrokerAccountEntity;
import com.py.demataccount.repository.PyBrokerAccountRepository;
import com.py.demataccount.repository.PyTradeGroupMemberRepository;
import com.py.demataccount.repository.PyTradeGroupRepository;
import com.py.demataccount.service.impl.PyBrokerAccountServiceImpl;
import com.py.entity.PyTradeGroupEntity;
import com.py.entity.PyTradeGroupMemberEntity;
import com.py.entity.PyUser;
import com.py.repo.PyUserRepository;
import com.py.service.PyTradeGroupService;
import org.apache.commons.lang3.StringUtils;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.ArrayList;
import java.util.List;
import java.util.stream.Collectors;
import org.json.JSONObject;

@Service
public class PyTradeGroupServiceImpl implements PyTradeGroupService {

    private static final Logger log = LoggerFactory.getLogger(PyTradeGroupServiceImpl.class);

    @Autowired
    private PyTradeGroupRepository pyTradeGroupRepository;

    @Autowired
    private PyTradeGroupMemberRepository pyTradeGroupMemberRepository;

    @Autowired
    private PyUserRepository pyUserRepository;

    @Autowired
    private PyBrokerAccountRepository pyBrokerAccountRepository;

    @Autowired
    private PyBrokerAccountServiceImpl pyBrokerAccountServiceImpl;

    // ── MAIN ENTRY POINT ─────────────────────────────────────────────────────
    @Override
    @Transactional
    public ApiResponse<?> groupOperations(PyTradeGroupRequestDto requestDto) {
        try {
            return switch (requestDto.getActionType()) {

                case CREATE ->
                        createGroup(requestDto);
                case UPDATE ->
                        updateGroup(requestDto);
                case DELETE ->
                        deleteGroup(requestDto);
                case ADD_MEMBERS ->
                        addMembers(requestDto);
                case REMOVE_MEMBER ->
                        removeMember(requestDto);

                default ->
                        ApiResponse.error(400, "Invalid action type");
            };
        } catch (RuntimeException e) {
            log.error("Group operation failed: {}", e.getMessage(), e);
            return ApiResponse.error(500, "Group operation failed: " + e.getMessage());
        }
    }

    // ── CREATE GROUP ─────────────────────────────────────────────────────────
    private ApiResponse<?> createGroup(PyTradeGroupRequestDto requestDto) {

        // 1. Validate pyId
        if (requestDto.getPyId() == null) {
            return ApiResponse.error(400, "pyId is required for CREATE");
        }

        // 2. Validate group name
        if (requestDto.getGroupName() == null || requestDto.getGroupName().isBlank()) {
            return ApiResponse.error(400, "Group name is required for CREATE");
        }

        // 3. Fetch user
        PyUser user = pyUserRepository.findById(requestDto.getPyId())
                .orElseThrow(() -> new RuntimeException(
                        "User not found with pyId: " + requestDto.getPyId()));

        // 4. Check role — only ADMIN and SUPER_ADMIN
        if (user.getRole() == PyUser.Role.USER) {
            return ApiResponse.error(403, "Only ADMIN and SUPER_ADMIN can create groups");
        }

        // 5. Check duplicate group name for this user
        if (pyTradeGroupRepository.existsByGroupNameAndCreatedBy(
                requestDto.getGroupName(), user)) {
            return ApiResponse.error(409,
                    "Group with name '" + requestDto.getGroupName()
                            + "' already exists for this user");
        }

        // 6. Create group
        PyTradeGroupEntity group = new PyTradeGroupEntity();
        group.setGroupName(requestDto.getGroupName());
        group.setDescription(requestDto.getDescription());
        group.setCreatedBy(user);
        group.setIsActive(true);

        PyTradeGroupEntity savedGroup = pyTradeGroupRepository.save(group);

        // 7. Add broker accounts if provided
        if (requestDto.getBrokerAccountIds() != null
                && !requestDto.getBrokerAccountIds().isEmpty()) {
            addBrokerAccountsToGroup(savedGroup, requestDto.getBrokerAccountIds());
        }

        log.info("Group created: {} by pyId: {}", savedGroup.getGroupName(),
                requestDto.getPyId());

        return ApiResponse.success("Group created successfully", null);
    }

    // ── UPDATE GROUP ─────────────────────────────────────────────────────────
    // ── UPDATE GROUP ─────────────────────────────────────────────────────────
    private ApiResponse<?> updateGroup(PyTradeGroupRequestDto requestDto) {

        if (requestDto.getGroupId() == null) {
            return ApiResponse.error(400, "groupId is required for UPDATE");
        }

        // Fetch group regardless of active status
        PyTradeGroupEntity group = pyTradeGroupRepository
                .findById(requestDto.getGroupId())
                .orElseThrow(() -> new RuntimeException(
                        "Group not found with id: " + requestDto.getGroupId()));

        // Update name if provided
        if (requestDto.getGroupName() != null
                && !requestDto.getGroupName().isBlank()) {
            group.setGroupName(requestDto.getGroupName());
        }

        // Update description if provided
        if (requestDto.getDescription() != null) {
            group.setDescription(requestDto.getDescription());
        }

        // ✅ Sync broker accounts — add new, remove missing
        if (requestDto.getBrokerAccountIds() != null) {
            syncBrokerAccountsInGroup(group, requestDto.getBrokerAccountIds());
        }

        log.info("Group updated: {}", group.getGroupName());

        return ApiResponse.success("Group updated successfully", null);
    }

    // ── HELPER: Sync Broker Accounts ─────────────────────────────────────────
// Add new ones, soft delete removed ones, keep existing ones
    private void syncBrokerAccountsInGroup(
            PyTradeGroupEntity group, List<Long> newBrokerAccountIds) {

        // 1. Get ALL members of group (active + inactive)
        List<PyTradeGroupMemberEntity> allMembers = pyTradeGroupMemberRepository
                .findByTradeGroup(group);

        // 2. Get current ACTIVE broker account IDs
        List<Long> activeBrokerIds = allMembers.stream()
                .filter(m -> Boolean.TRUE.equals(m.getIsLinked()))
                .map(m -> m.getBrokerAccount().getId())
                .toList();

        // 3. Get ALL existing broker IDs (active + inactive)
        List<Long> allExistingBrokerIds = allMembers.stream()
                .map(m -> m.getBrokerAccount().getId())
                .toList();

        for (Long newBrokerId : newBrokerAccountIds) {

            if (!allExistingBrokerIds.contains(newBrokerId)) {
                // ── CASE 1: Brand new broker → ADD ───────────────────────────
                try {
                    PyBrokerAccountEntity brokerAccount = pyBrokerAccountRepository
                            .findById(newBrokerId)
                            .orElseThrow(() -> new RuntimeException(
                                    "Broker account not found: " + newBrokerId));

                    PyTradeGroupMemberEntity member = new PyTradeGroupMemberEntity();
                    member.setTradeGroup(group);
                    member.setBrokerAccount(brokerAccount);
                    member.setIsLinked(brokerAccount.getActive());
                    pyTradeGroupMemberRepository.save(member);

                    log.info("Group {} — NEW broker added: {}",
                            group.getGroupName(),
                            brokerAccount.getClientId());

                } catch (Exception e) {
                    log.error("Failed to add broker {} to group: {}",
                            newBrokerId, e.getMessage());
                }

            } else if (!activeBrokerIds.contains(newBrokerId)) {
                // ── CASE 2: Broker exists but inactive → RESTORE ─────────────
                allMembers.stream()
                        .filter(m -> m.getBrokerAccount().getId().equals(newBrokerId))
                        .findFirst()
                        .ifPresent(member -> {
                            member.setIsLinked(true);
                            pyTradeGroupMemberRepository.save(member);
                            log.info("Group {} — broker RESTORED: {}",
                                    group.getGroupName(),
                                    member.getBrokerAccount().getClientId());
                        });
            }
            // ── CASE 3: Already active → keep as is (do nothing) ─────────────
        }

        // 4. Soft delete brokers not in new list but currently active
        for (PyTradeGroupMemberEntity member : allMembers) {
            Long memberId = member.getBrokerAccount().getId();
            if (Boolean.TRUE.equals(member.getIsLinked())
                    && !newBrokerAccountIds.contains(memberId)) {
                member.setIsLinked(false);
                pyTradeGroupMemberRepository.save(member);
                log.info("Group {} — broker DEACTIVATED: {}",
                        group.getGroupName(),
                        member.getBrokerAccount().getClientId());
            }
        }

        log.info("Group {} — sync complete. newList={}",
                group.getGroupName(), newBrokerAccountIds);
    }

    // ── DELETE GROUP — soft delete ────────────────────────────────────────────
    private ApiResponse<?> deleteGroup(PyTradeGroupRequestDto requestDto) {

        if (requestDto.getGroupId() == null) {
            return ApiResponse.error(400, "groupId is required for DELETE");
        }

        PyTradeGroupEntity group = pyTradeGroupRepository.findById(requestDto.getGroupId())
                .orElseThrow(() -> new RuntimeException(
                        "Group not found with id: " + requestDto.getGroupId()));

        // Soft delete group
        group.setIsActive(false);

        log.info("Group soft deleted: {}", group.getGroupName());

        return ApiResponse.success("Group deleted successfully", null);
    }

    // ── ADD MEMBERS ──────────────────────────────────────────────────────────
    private ApiResponse<?> addMembers(PyTradeGroupRequestDto requestDto) {

        // 1. Validate
        if (requestDto.getGroupId() == null) {
            return ApiResponse.error(400, "groupId is required for ADD_MEMBERS");
        }
        if (requestDto.getBrokerAccountIds() == null
                || requestDto.getBrokerAccountIds().isEmpty()) {
            return ApiResponse.error(400, "brokerAccountIds are required for ADD_MEMBERS");
        }

        // 2. Fetch group
        PyTradeGroupEntity group = pyTradeGroupRepository
                .findByIdAndIsActive(requestDto.getGroupId(), true)
                .orElseThrow(() -> new RuntimeException(
                        "Group not found with id: " + requestDto.getGroupId()));

        // 3. Add broker accounts
        List<String> skipped = addBrokerAccountsToGroup(
                group, requestDto.getBrokerAccountIds());

        String message = skipped.isEmpty()
                ? "Members added successfully"
                : "Members added. Skipped already existing: " + skipped;

        return ApiResponse.success(message, null);
    }

    // ── REMOVE MEMBER ────────────────────────────────────────────────────────
    @Transactional
    private ApiResponse<?> removeMember(PyTradeGroupRequestDto requestDto) {

        if (requestDto.getGroupId() == null) {
            return ApiResponse.error(400, "groupId is required for REMOVE_MEMBER");
        }
        if (requestDto.getBrokerAccountId() == null) {
            return ApiResponse.error(400, "brokerAccountId is required for REMOVE_MEMBER");
        }

        PyTradeGroupEntity group = pyTradeGroupRepository.findById(requestDto.getGroupId())
                .orElseThrow(() -> new RuntimeException(
                        "Group not found with id: " + requestDto.getGroupId()));

        PyBrokerAccountEntity brokerAccount = pyBrokerAccountRepository
                .findById(requestDto.getBrokerAccountId())
                .orElseThrow(() -> new RuntimeException(
                        "Broker account not found: " + requestDto.getBrokerAccountId()));

        PyTradeGroupMemberEntity member = pyTradeGroupMemberRepository
                .findByTradeGroupAndBrokerAccount(group, brokerAccount)
                .orElseThrow(() -> new RuntimeException(
                        "Broker account not found in this group"));

        // Soft delete — set inactive
        member.setIsLinked(false);

        log.info("Broker account {} soft deleted from group {}",
                brokerAccount.getClientId(), group.getGroupName());

        return ApiResponse.success("Member removed successfully", null);
    }

    // ── GET GROUP BY ID ──────────────────────────────────────────────────────
    @Override
    @Transactional(readOnly = true)
    public ApiResponse<PyTradeGroupResponseDto> getGroupById(Long groupId, boolean getBalance) {
        try {
            PyTradeGroupEntity group = pyTradeGroupRepository
                    .findByIdAndIsActive(groupId, true)
                    .orElseThrow(() -> new RuntimeException(
                            "Group not found with id: " + groupId));

            return ApiResponse.success("Group fetched successfully",
                    mapToResponseDto(group, getBalance));
        } catch (RuntimeException e) {
            log.error("Get group by id failed | groupId={}: {}", groupId, e.getMessage(), e);
            return ApiResponse.error(404, "Group not found");
        }
    }

    // ── GET ALL GROUPS BY USER ───────────────────────────────────────────────
    @Override
    @Transactional(readOnly = true)
    public ApiResponse<List<PyTradeGroupResponseDto>> getAllGroupsByUser(Long pyId, boolean getBalance) {
        try {
            List<PyTradeGroupEntity> groups;
            if (pyId == null || pyId <= 0) {
                groups = pyTradeGroupRepository.findByIsActive(true);
            } else {
                java.util.Optional<PyUser> userOpt = pyUserRepository.findById(pyId);
                if (userOpt.isEmpty()) {
                    groups = pyTradeGroupRepository.findByIsActive(true);
                } else {
                    PyUser user = userOpt.get();
                    if (user.getRole() == PyUser.Role.SUPER_ADMIN) {
                        groups = pyTradeGroupRepository.findAll();
                    } else {
                        groups = pyTradeGroupRepository.findByCreatedBy(user);
                        if (groups.isEmpty()) {
                            groups = pyTradeGroupRepository.findByIsActive(true);
                        }
                    }
                }
            }

            if (groups == null || groups.isEmpty()) {
                return ApiResponse.success("Groups fetched successfully", new ArrayList<>());
            }

            List<PyTradeGroupResponseDto> response = groups.stream()
                    .map(group -> mapToResponseDto(group, getBalance))
                    .collect(Collectors.toList());

            return ApiResponse.success("Groups fetched successfully", response);

        } catch (Exception e) {
            log.warn("Get all groups by user fallback | pyId={}: {}", pyId, e.getMessage());
            return ApiResponse.success("Groups fetched successfully", new ArrayList<>());
        }
    }

    // ── HELPER: Add Broker Accounts to Group ─────────────────────────────────
    private List<String> addBrokerAccountsToGroup(
            PyTradeGroupEntity group, List<Long> brokerAccountIds) {

        List<String> skipped = new ArrayList<>();

        for (Long brokerAccountId : brokerAccountIds) {
            try {
                PyBrokerAccountEntity brokerAccount = pyBrokerAccountRepository
                        .findById(brokerAccountId)
                        .orElseThrow(() -> new RuntimeException(
                                "Broker account not found: " + brokerAccountId));

                // Check if already exists in group
                if (pyTradeGroupMemberRepository.existsByTradeGroupAndBrokerAccount(
                        group, brokerAccount)) {
                    skipped.add(brokerAccount.getClientId()
                            + " already exists in group");
                    continue;
                }

                // Add member
                PyTradeGroupMemberEntity member = new PyTradeGroupMemberEntity();
                member.setTradeGroup(group);
                member.setBrokerAccount(brokerAccount);
                pyTradeGroupMemberRepository.save(member);

                log.info("Broker account {} added to group {}",
                        brokerAccount.getClientId(), group.getGroupName());

            } catch (RuntimeException e) {
                skipped.add("Error adding brokerAccountId "
                        + brokerAccountId + ": " + e.getMessage());
            }
        }

        return skipped;
    }

    // ── HELPER: Map Entity to Response DTO ───────────────────────────────────
    private PyTradeGroupResponseDto mapToResponseDto(PyTradeGroupEntity group, boolean getBalance) {

        PyTradeGroupResponseDto dto = new PyTradeGroupResponseDto();
        dto.setGroupId(group.getId());
        dto.setGroupName(group.getGroupName());
        dto.setDescription(group.getDescription());
        dto.setCreatedByPyId(group.getCreatedBy().getId());
        dto.setCreatedByName(group.getCreatedBy().getFullName());
        dto.setIsActive(group.getIsActive());
        dto.setCreatedAt(group.getCreatedAt());

        // Count only ACTIVE members
        dto.setMemberCount(pyTradeGroupMemberRepository
                .countByTradeGroupAndIsLinked(group, true));

        // Fetch only ACTIVE members
        List<PyTradeGroupMemberEntity> activeMembers = pyTradeGroupMemberRepository
                .findByTradeGroup(group);

        List<PyTradeGroupMemberResponseDto> memberDtos = activeMembers.stream()
                .map(member -> mapToMemberResponseDto(member, getBalance))
                .collect(Collectors.toList());

        dto.setMembers(memberDtos);

        return dto;
    }

    // ── HELPER: Map Member Entity to Response DTO ────────────────────────────
    private PyTradeGroupMemberResponseDto mapToMemberResponseDto(
            PyTradeGroupMemberEntity member, boolean getBalance) {

        PyTradeGroupMemberResponseDto dto = new PyTradeGroupMemberResponseDto();
        dto.setMemberId(member.getId());
        dto.setBrokerAccountId(member.getBrokerAccount().getId());
        dto.setClientId(member.getBrokerAccount().getClientId());
        dto.setUserName(member.getBrokerAccount().getUserName());
        dto.setBrokerType(member.getBrokerAccount().getBrokerType());
        dto.setAddedAt(member.getAddedAt());
        dto.setLinked(member.getIsLinked());
        dto.setMemberActive(member.getBrokerAccount().getActive());
        if(getBalance && StringUtils.isNotEmpty(member.getBrokerAccount().getBrokerRegisteredIp())) {
            try {
                JSONObject rmsData = pyBrokerAccountServiceImpl.getRMS(member.getBrokerAccount());
                BrokerRmsDto rms = pyBrokerAccountServiceImpl.mapToRmsDto(member.getBrokerAccount().getBrokerType(), rmsData);
                dto.setCashBalance(rms.getAvailableCash());
                dto.setBrokerRmsDto(rms);
            } catch (Exception e) {
                log.warn("RMS failed for clientId={}: {}",
                        member.getBrokerAccount().getClientId(), e.getMessage());
                dto.setCashBalance(0.0);
            }
        }
        return dto;
    }
}
