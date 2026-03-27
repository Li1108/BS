package com.nursing.dto.admin;

import com.alibaba.excel.annotation.ExcelProperty;
import com.alibaba.excel.annotation.format.DateTimeFormat;
import com.alibaba.excel.annotation.write.style.ColumnWidth;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.math.BigDecimal;
import java.time.LocalDateTime;

/**
 * 订单导出Excel DTO
 */
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class OrderExportDTO {

    @ExcelProperty("订单号")
    @ColumnWidth(25)
    private String orderNo;

    @ExcelProperty("服务名称")
    @ColumnWidth(15)
    private String serviceName;

    @ExcelProperty("订单金额")
    @ColumnWidth(12)
    private BigDecimal totalAmount;

    @ExcelProperty("平台服务费")
    @ColumnWidth(12)
    private BigDecimal platformFee;

    @ExcelProperty("护士收入")
    @ColumnWidth(12)
    private BigDecimal nurseIncome;

    @ExcelProperty("联系人")
    @ColumnWidth(12)
    private String contactName;

    @ExcelProperty("联系电话")
    @ColumnWidth(15)
    private String contactPhone;

    @ExcelProperty("服务地址")
    @ColumnWidth(35)
    private String address;

    @ExcelProperty("预约时间")
    @ColumnWidth(20)
    @DateTimeFormat("yyyy-MM-dd HH:mm")
    private LocalDateTime appointmentTime;

    @ExcelProperty("订单状态")
    @ColumnWidth(12)
    private String statusDesc;

    @ExcelProperty("支付状态")
    @ColumnWidth(10)
    private String payStatusDesc;

    @ExcelProperty("护士姓名")
    @ColumnWidth(12)
    private String nurseName;

    @ExcelProperty("护士电话")
    @ColumnWidth(15)
    private String nursePhone;

    @ExcelProperty("用户备注")
    @ColumnWidth(25)
    private String remark;

    @ExcelProperty("创建时间")
    @ColumnWidth(20)
    @DateTimeFormat("yyyy-MM-dd HH:mm:ss")
    private LocalDateTime createdAt;
}
