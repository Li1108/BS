package com.nursing.controller;

import com.nursing.common.Result;
import com.nursing.dto.auth.PasswordLoginRequest;
import com.nursing.entity.SysUser;
import com.nursing.mapper.SysUserMapper;
import com.nursing.utils.JwtUtils;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.security.crypto.password.PasswordEncoder;

import java.util.Map;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertNotNull;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class AdminAuthControllerTest {

    @Mock
    private SysUserMapper sysUserMapper;
    @Mock
    private JwtUtils jwtUtils;
    @Mock
    private PasswordEncoder passwordEncoder;

    @InjectMocks
    private AdminAuthController adminAuthController;

    private PasswordLoginRequest request;

    @BeforeEach
    void setUp() {
        request = new PasswordLoginRequest();
        request.setPhone("18800000000");
        request.setPassword("admin123");
    }

    @Test
    void adminLoginShouldSucceed() {
        SysUser user = SysUser.builder()
                .id(1L)
                .phone("18800000000")
                .password("admin123")
                .status(SysUser.StatusEnum.NORMAL)
                .build();

        when(sysUserMapper.findByPhone("18800000000")).thenReturn(user);
        when(sysUserMapper.findRoleCodeByUserId(1L)).thenReturn("ADMIN_SUPER");
        when(jwtUtils.generateToken(1L, "18800000000", "ADMIN_SUPER")).thenReturn("jwt-token");

        Result<Map<String, Object>> result = adminAuthController.login(request);

        assertEquals(0, result.getCode());
        assertNotNull(result.getData());
        assertEquals("ADMIN_SUPER", result.getData().get("role"));
        assertEquals("jwt-token", result.getData().get("token"));
    }

    @Test
    void adminLoginShouldFailWhenPasswordMismatch() {
        SysUser user = SysUser.builder()
                .id(1L)
                .phone("18800000000")
                .password("$2a$10$hashed")
                .status(SysUser.StatusEnum.NORMAL)
                .build();

        when(sysUserMapper.findByPhone("18800000000")).thenReturn(user);
        when(sysUserMapper.findRoleCodeByUserId(1L)).thenReturn("ADMIN_SUPER");
        when(passwordEncoder.matches(any(), any())).thenReturn(false);

        Result<Map<String, Object>> result = adminAuthController.login(request);
        assertEquals(400, result.getCode());
    }
}
