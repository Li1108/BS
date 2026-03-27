package com.nursing.controller;

import org.springframework.security.crypto.bcrypt.BCryptPasswordEncoder;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/v1/test")
public class TestController {
    
    @GetMapping("/bcrypt")
    public String generateBcrypt() {
        BCryptPasswordEncoder encoder = new BCryptPasswordEncoder();
        
        // 生成123456的BCrypt哈希
        String hash = encoder.encode("123456");
        
        return "BCrypt hash for '123456': " + hash;
    }
}