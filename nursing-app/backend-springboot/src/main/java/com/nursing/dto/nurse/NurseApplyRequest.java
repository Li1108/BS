package com.nursing.dto.nurse;

import jakarta.validation.constraints.NotBlank;
import lombok.Data;

@Data
public class NurseApplyRequest {
    @NotBlank(message = "真实姓名不能为空")
    private String realName;

    private String idCardNo;

    @NotBlank(message = "身份证正面照片不能为空")
    private String idCardPhotoFront;

    @NotBlank(message = "身份证背面照片不能为空")
    private String idCardPhotoBack;

    @NotBlank(message = "执业证照片不能为空")
    private String certificatePhoto;

    private String serviceArea;
}

