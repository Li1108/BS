package com.nursing;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.scheduling.annotation.EnableScheduling;

/**
 * 互联网+护理服务APP 启动类
 */
@SpringBootApplication
@EnableScheduling
public class NursingServiceApplication {

    public static void main(String[] args) {
        SpringApplication.run(NursingServiceApplication.class, args);
    }
}
