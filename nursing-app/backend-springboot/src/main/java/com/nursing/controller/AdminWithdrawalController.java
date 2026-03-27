package com.nursing.controller;

import com.baomidou.mybatisplus.core.conditions.query.LambdaQueryWrapper;
import com.baomidou.mybatisplus.core.metadata.IPage;
import com.baomidou.mybatisplus.extension.plugins.pagination.Page;
import com.itextpdf.text.BaseColor;
import com.itextpdf.text.Document;
import com.itextpdf.text.DocumentException;
import com.itextpdf.text.Element;
import com.itextpdf.text.Font;
import com.itextpdf.text.PageSize;
import com.itextpdf.text.Paragraph;
import com.itextpdf.text.Phrase;
import com.itextpdf.text.pdf.BaseFont;
import com.itextpdf.text.pdf.PdfPCell;
import com.itextpdf.text.pdf.PdfPTable;
import com.itextpdf.text.pdf.PdfWriter;
import com.nursing.common.Result;
import com.nursing.entity.NurseWallet;
import com.nursing.entity.Notification;
import com.nursing.entity.OperationLog;
import com.nursing.entity.SysUser;
import com.nursing.entity.Withdrawal;
import com.nursing.entity.WalletLog;
import com.nursing.mapper.NurseWalletMapper;
import com.nursing.mapper.NotificationMapper;
import com.nursing.mapper.OperationLogMapper;
import com.nursing.mapper.SysUserMapper;
import com.nursing.mapper.WalletLogMapper;
import com.nursing.mapper.WithdrawalMapper;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.util.StringUtils;
import org.springframework.web.bind.annotation.*;

import jakarta.servlet.http.HttpServletResponse;

import java.io.ByteArrayOutputStream;
import java.io.IOException;
import java.net.URLEncoder;
import java.nio.charset.StandardCharsets;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.time.LocalTime;
import java.math.BigDecimal;
import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

/**
 * 管理员提现审核控制器
 */
@Slf4j
@RestController
@RequestMapping("/admin/withdraw")
@RequiredArgsConstructor
@PreAuthorize("hasRole('ADMIN_SUPER')")
public class AdminWithdrawalController {

    private final WithdrawalMapper withdrawalMapper;
    private final NurseWalletMapper nurseWalletMapper;
    private final NotificationMapper notificationMapper;
    private final OperationLogMapper operationLogMapper;
    private final SysUserMapper sysUserMapper;
    private final WalletLogMapper walletLogMapper;

    /**
     * 提现列表（分页+筛选）
     * GET /api/admin/withdraw/list?status=&nursePhone=&nurseName=&pageNo=&pageSize=
     */
    @GetMapping("/list")
    public Result<IPage<Withdrawal>> getWithdrawalList(
            @RequestParam(required = false) Integer status,
            @RequestParam(required = false) String nursePhone,
            @RequestParam(required = false) String nurseName,
            @RequestParam(required = false) String startDate,
            @RequestParam(required = false) String endDate,
            @RequestParam(defaultValue = "1") Integer pageNo,
            @RequestParam(defaultValue = "10") Integer pageSize) {
        LambdaQueryWrapper<Withdrawal> wrapper = buildFilterWrapper(
                status,
                nursePhone,
                nurseName,
                startDate,
                endDate
        );

        IPage<Withdrawal> page = withdrawalMapper.selectPage(new Page<>(pageNo, pageSize), wrapper);
        return Result.success(page);
    }

    /**
     * 导出提现报表（PDF）
     * GET /api/admin/withdraw/export/pdf
     */
    @GetMapping("/export/pdf")
    public void exportWithdrawalPdf(
            @RequestParam(required = false) Integer status,
            @RequestParam(required = false) String nursePhone,
            @RequestParam(required = false) String nurseName,
            @RequestParam(required = false) String startDate,
            @RequestParam(required = false) String endDate,
            HttpServletResponse response) throws IOException {

        LambdaQueryWrapper<Withdrawal> wrapper = buildFilterWrapper(
                status,
                nursePhone,
                nurseName,
                startDate,
                endDate
        );
        wrapper.last("LIMIT 5000");

        List<Withdrawal> rows = withdrawalMapper.selectList(wrapper);

        ByteArrayOutputStream bos = new ByteArrayOutputStream();
        try {
            Document document = new Document(PageSize.A4.rotate(), 24, 24, 24, 24);
            PdfWriter.getInstance(document, bos);
            document.open();

            BaseFont baseFont = BaseFont.createFont("STSong-Light", "UniGB-UCS2-H", BaseFont.NOT_EMBEDDED);
            Font titleFont = new Font(baseFont, 16, Font.BOLD);
            Font textFont = new Font(baseFont, 10, Font.NORMAL);
            Font headerFont = new Font(baseFont, 10, Font.BOLD, BaseColor.WHITE);

            Paragraph title = new Paragraph("提现财务报表", titleFont);
            title.setAlignment(Element.ALIGN_CENTER);
            document.add(title);

            String filterLine = String.format(
                    "导出时间：%s    状态：%s    护士手机号：%s    护士姓名：%s    日期范围：%s ~ %s",
                    LocalDateTime.now(),
                    statusLabel(status),
                    StringUtils.hasText(nursePhone) ? nursePhone : "全部",
                    StringUtils.hasText(nurseName) ? nurseName : "全部",
                    StringUtils.hasText(startDate) ? startDate : "不限",
                    StringUtils.hasText(endDate) ? endDate : "不限"
            );
            Paragraph meta = new Paragraph(filterLine, textFont);
            meta.setSpacingBefore(8f);
            meta.setSpacingAfter(10f);
            document.add(meta);

            PdfPTable table = new PdfPTable(new float[]{1f, 1.4f, 1.8f, 1.6f, 1.2f, 1.8f, 1.8f, 2f});
            table.setWidthPercentage(100);

            addHeaderCell(table, "ID", headerFont);
            addHeaderCell(table, "护士ID", headerFont);
            addHeaderCell(table, "收款人", headerFont);
            addHeaderCell(table, "支付宝账号", headerFont);
            addHeaderCell(table, "提现金额", headerFont);
            addHeaderCell(table, "状态", headerFont);
            addHeaderCell(table, "申请时间", headerFont);
            addHeaderCell(table, "审核/打款时间", headerFont);

            BigDecimal totalAmount = BigDecimal.ZERO;
            for (Withdrawal item : rows) {
                totalAmount = totalAmount.add(item.getWithdrawAmount() == null ? BigDecimal.ZERO : item.getWithdrawAmount());

                addBodyCell(table, String.valueOf(item.getId()), textFont);
                addBodyCell(table, String.valueOf(item.getNurseUserId()), textFont);
                addBodyCell(table, item.getAccountHolder(), textFont);
                addBodyCell(table, item.getBankAccount(), textFont);
                addBodyCell(table, item.getWithdrawAmount() == null ? "0.00" : item.getWithdrawAmount().toPlainString(), textFont, Element.ALIGN_RIGHT);
                addBodyCell(table, statusLabel(item.getStatus()), textFont);
                addBodyCell(table, item.getCreateTime() == null ? "-" : item.getCreateTime().toString(), textFont);

                String auditOrPayTime = "-";
                if (item.getPayTime() != null) {
                    auditOrPayTime = item.getPayTime().toString();
                } else if (item.getAuditTime() != null) {
                    auditOrPayTime = item.getAuditTime().toString();
                }
                addBodyCell(table, auditOrPayTime, textFont);
            }

            PdfPCell summaryCell = new PdfPCell(
                    new Phrase(
                            "合计笔数：" + rows.size() + "    合计金额：¥" + totalAmount.toPlainString(),
                            textFont
                    )
            );
            summaryCell.setColspan(8);
            summaryCell.setHorizontalAlignment(Element.ALIGN_RIGHT);
            summaryCell.setPadding(6f);
            table.addCell(summaryCell);

            document.add(table);
            document.close();
        } catch (DocumentException e) {
            throw new IOException("生成PDF失败", e);
        }

        Long adminId = (Long) SecurityContextHolder.getContext().getAuthentication().getPrincipal();
        writeLog(adminId, "EXPORT_WITHDRAW_PDF", "导出提现PDF报表, count=" + rows.size(), "/admin/withdraw/export/pdf", "GET");

        String fileName = "withdraw_report_" + LocalDate.now() + ".pdf";
        String encoded = URLEncoder.encode(fileName, StandardCharsets.UTF_8).replaceAll("\\+", "%20");
        response.setContentType("application/pdf");
        response.setCharacterEncoding(StandardCharsets.UTF_8.name());
        response.setHeader("Content-Disposition", "attachment;filename*=UTF-8''" + encoded);
        response.getOutputStream().write(bos.toByteArray());
        response.getOutputStream().flush();
    }

    /**
     * 提现详情
     * GET /api/admin/withdraw/detail/{id}
     */
    @GetMapping("/detail/{id}")
    public Result<Withdrawal> getWithdrawalDetail(@PathVariable Long id) {
        Withdrawal withdrawal = withdrawalMapper.selectById(id);
        if (withdrawal == null) {
            return Result.notFound("提现记录不存在");
        }
        return Result.success(withdrawal);
    }

    /**
     * 审核通过
     * POST /api/admin/withdraw/approve/{id}
     * body: { remark }
     */
    @PostMapping("/approve/{id}")
    public Result<Void> approveWithdrawal(@PathVariable Long id, @RequestBody Map<String, String> body) {
        Long adminId = (Long) SecurityContextHolder.getContext().getAuthentication().getPrincipal();
        String remark = body != null ? body.get("remark") : null;

        Withdrawal withdrawal = withdrawalMapper.selectById(id);
        if (withdrawal == null) {
            return Result.notFound("提现记录不存在");
        }
        if (withdrawal.getStatus() != Withdrawal.StatusEnum.PENDING) {
            return Result.badRequest("只有待审核的提现记录才能审核");
        }

        withdrawal.setStatus(Withdrawal.StatusEnum.APPROVED);
        withdrawal.setAuditAdminId(adminId);
        withdrawal.setAuditRemark(remark);
        withdrawal.setAuditTime(LocalDateTime.now());
        withdrawal.setUpdateTime(LocalDateTime.now());
        withdrawalMapper.updateById(withdrawal);

        notifyNurseWithdrawResult(withdrawal, "提现审核通过", "您的提现申请已审核通过，等待打款。");

        // 写操作日志
        writeLog(adminId, "APPROVE_WITHDRAWAL", "审核通过提现申请, id=" + id, "/admin/withdraw/approve/" + id, "POST");

        log.info("管理员{}审核通过提现申请, withdrawalId={}", adminId, id);
        return Result.success();
    }

    /**
     * 审核拒绝
     * POST /api/admin/withdraw/reject/{id}
     * body: { remark }
     */
    @PostMapping("/reject/{id}")
    public Result<Void> rejectWithdrawal(@PathVariable Long id, @RequestBody Map<String, String> body) {
        Long adminId = (Long) SecurityContextHolder.getContext().getAuthentication().getPrincipal();
        String remark = body != null ? body.get("remark") : null;

        Withdrawal withdrawal = withdrawalMapper.selectById(id);
        if (withdrawal == null) {
            return Result.notFound("提现记录不存在");
        }
        if (withdrawal.getStatus() != Withdrawal.StatusEnum.PENDING) {
            return Result.badRequest("只有待审核的提现记录才能审核");
        }

        withdrawal.setStatus(Withdrawal.StatusEnum.REJECTED);
        withdrawal.setAuditAdminId(adminId);
        withdrawal.setAuditRemark(remark);
        withdrawal.setAuditTime(LocalDateTime.now());
        withdrawal.setUpdateTime(LocalDateTime.now());
        withdrawalMapper.updateById(withdrawal);

        // 拒绝后，退还金额到护士钱包
        NurseWallet wallet = nurseWalletMapper.selectOne(
                new LambdaQueryWrapper<NurseWallet>().eq(NurseWallet::getNurseUserId, withdrawal.getNurseUserId())
        );
        if (wallet != null) {
            wallet.setBalance(wallet.getBalance().add(withdrawal.getWithdrawAmount()));
            wallet.setUpdateTime(LocalDateTime.now());
            nurseWalletMapper.updateById(wallet);
        }

        notifyNurseWithdrawResult(
            withdrawal,
            "提现申请被驳回",
            "您的提现申请已被驳回，金额已退回钱包余额。"
                + (StringUtils.hasText(remark) ? " 原因：" + remark : "")
        );

        writeLog(adminId, "REJECT_WITHDRAWAL", "拒绝提现申请, id=" + id + ", 原因: " + remark, "/admin/withdraw/reject/" + id, "POST");

        log.info("管理员{}拒绝提现申请, withdrawalId={}", adminId, id);
        return Result.success();
    }

    /**
     * 确认打款
     * POST /api/admin/withdraw/pay/{id}
     * body: { payNo, remark }
     */
    @PostMapping("/pay/{id}")
    public Result<Void> payWithdrawal(@PathVariable Long id, @RequestBody Map<String, String> body) {
        Long adminId = (Long) SecurityContextHolder.getContext().getAuthentication().getPrincipal();
        String payNo = body != null ? body.get("payNo") : null;
        String remark = body != null ? body.get("remark") : null;

        Withdrawal withdrawal = withdrawalMapper.selectById(id);
        if (withdrawal == null) {
            return Result.notFound("提现记录不存在");
        }
        if (withdrawal.getStatus() != Withdrawal.StatusEnum.APPROVED) {
            return Result.badRequest("只有已审核通过的提现记录才能打款");
        }

        withdrawal.setStatus(Withdrawal.StatusEnum.PAID);
        withdrawal.setAuditRemark(remark);
        withdrawal.setPayTime(LocalDateTime.now());
        withdrawal.setUpdateTime(LocalDateTime.now());
        withdrawalMapper.updateById(withdrawal);

        NurseWallet wallet = nurseWalletMapper.selectOne(
            new LambdaQueryWrapper<NurseWallet>().eq(NurseWallet::getNurseUserId, withdrawal.getNurseUserId())
        );
        if (wallet != null) {
            BigDecimal totalWithdraw = wallet.getTotalWithdraw() == null
                ? BigDecimal.ZERO
                : wallet.getTotalWithdraw();
            wallet.setTotalWithdraw(totalWithdraw.add(withdrawal.getWithdrawAmount()));
            wallet.setUpdateTime(LocalDateTime.now());
            nurseWalletMapper.updateById(wallet);
        }

        // 写入钱包流水（提现支出），用于护士端收支明细展示。
        String withdrawRefNo = buildWithdrawRefNo(id);
        WalletLog existsLog = walletLogMapper.selectOne(
            new LambdaQueryWrapper<WalletLog>()
                .eq(WalletLog::getNurseUserId, withdrawal.getNurseUserId())
                .eq(WalletLog::getOrderNo, withdrawRefNo)
                .last("limit 1")
        );
        if (existsLog == null) {
            NurseWallet currentWallet = nurseWalletMapper.selectOne(
                new LambdaQueryWrapper<NurseWallet>()
                    .eq(NurseWallet::getNurseUserId, withdrawal.getNurseUserId())
                    .last("limit 1")
            );
            BigDecimal balanceAfter = currentWallet != null && currentWallet.getBalance() != null
                ? currentWallet.getBalance()
                : BigDecimal.ZERO;

            WalletLog walletLog = WalletLog.builder()
                .nurseUserId(withdrawal.getNurseUserId())
                .orderNo(withdrawRefNo)
                .changeType(2) // 2=提现支出
                .changeAmount(withdrawal.getWithdrawAmount().negate())
                .balanceAfter(balanceAfter)
                .remark("提现打款成功")
                .createTime(LocalDateTime.now())
                .build();
            walletLogMapper.insert(walletLog);
        }

        notifyNurseWithdrawResult(withdrawal, "提现打款成功", "您的提现申请已打款完成，请注意查收。参考号：" + buildWithdrawRefNo(id));

        writeLog(adminId, "PAY_WITHDRAWAL", "确认打款, id=" + id + ", payNo=" + payNo, "/admin/withdraw/pay/" + id, "POST");

        log.info("管理员{}确认打款, withdrawalId={}, payNo={}", adminId, id, payNo);
        return Result.success();
    }

    private String buildWithdrawRefNo(Long withdrawId) {
        return "WD-" + withdrawId;
    }

    private void notifyNurseWithdrawResult(Withdrawal withdrawal, String title, String content) {
        if (withdrawal == null || withdrawal.getNurseUserId() == null) {
            return;
        }
        notificationMapper.insert(Notification.builder()
            .receiverUserId(withdrawal.getNurseUserId())
            .receiverRole("NURSE")
            .title(title)
            .content(content)
            .bizType("WITHDRAW")
            .bizId(String.valueOf(withdrawal.getId()))
            .readFlag(0)
            .createTime(LocalDateTime.now())
            .build());
    }

    private LambdaQueryWrapper<Withdrawal> buildFilterWrapper(
            Integer status,
            String nursePhone,
            String nurseName,
            String startDate,
            String endDate) {
        LambdaQueryWrapper<Withdrawal> wrapper = new LambdaQueryWrapper<Withdrawal>()
                .eq(status != null, Withdrawal::getStatus, status)
                .orderByDesc(Withdrawal::getCreateTime);

        if (StringUtils.hasText(startDate)) {
            wrapper.ge(Withdrawal::getCreateTime, LocalDate.parse(startDate).atStartOfDay());
        }
        if (StringUtils.hasText(endDate)) {
            wrapper.le(Withdrawal::getCreateTime, LocalDate.parse(endDate).atTime(LocalTime.MAX));
        }

        if (StringUtils.hasText(nursePhone)) {
            SysUser nurse = sysUserMapper.findByPhone(nursePhone);
            if (nurse != null) {
                wrapper.eq(Withdrawal::getNurseUserId, nurse.getId());
            } else {
                wrapper.eq(Withdrawal::getNurseUserId, -1L);
            }
        }
        if (StringUtils.hasText(nurseName)) {
            wrapper.like(Withdrawal::getAccountHolder, nurseName);
        }
        return wrapper;
    }

    private String statusLabel(Integer status) {
        if (status == null) {
            return "全部";
        }
        return switch (status) {
            case 0 -> "待审核";
            case 1 -> "已审核";
            case 2 -> "已驳回";
            case 3 -> "已打款";
            default -> "未知";
        };
    }

    private void addHeaderCell(PdfPTable table, String text, Font font) {
        PdfPCell cell = new PdfPCell(new Phrase(text, font));
        cell.setHorizontalAlignment(Element.ALIGN_CENTER);
        cell.setVerticalAlignment(Element.ALIGN_MIDDLE);
        cell.setPadding(6f);
        cell.setBackgroundColor(new BaseColor(64, 158, 255));
        table.addCell(cell);
    }

    private void addBodyCell(PdfPTable table, String text, Font font) {
        addBodyCell(table, text, font, Element.ALIGN_LEFT);
    }

    private void addBodyCell(PdfPTable table, String text, Font font, int alignment) {
        PdfPCell cell = new PdfPCell(new Phrase(text == null ? "-" : text, font));
        cell.setHorizontalAlignment(alignment);
        cell.setVerticalAlignment(Element.ALIGN_MIDDLE);
        cell.setPadding(5f);
        table.addCell(cell);
    }

    private void writeLog(Long adminId, String actionType, String actionDesc, String requestPath, String requestMethod) {
        OperationLog opLog = OperationLog.builder()
                .adminUserId(adminId)
                .actionType(actionType)
                .actionDesc(actionDesc)
                .requestPath(requestPath)
                .requestMethod(requestMethod)
                .createTime(LocalDateTime.now())
                .build();
        operationLogMapper.insert(opLog);
    }

    /**
     * 批量审核/打款
     */
    @PostMapping("/batch/audit")
    public Result<?> batchAudit(@RequestBody Map<String, Object> body) {
        Object idsObj = body == null ? null : body.get("ids");
        String action = body == null || body.get("action") == null ? "" : body.get("action").toString();
        String remark = body == null || body.get("remark") == null ? null : body.get("remark").toString();

        if (!(idsObj instanceof List<?> ids) || ids.isEmpty()) {
            return Result.badRequest("ids 不能为空");
        }
        if (!("approve".equalsIgnoreCase(action) || "reject".equalsIgnoreCase(action) || "pay".equalsIgnoreCase(action))) {
            return Result.badRequest("action 仅支持 approve/reject/pay");
        }

        Long adminId = (Long) SecurityContextHolder.getContext().getAuthentication().getPrincipal();
        List<Map<String, Object>> results = new ArrayList<>();

        for (Object idObj : ids) {
            Long id;
            try {
                id = Long.parseLong(String.valueOf(idObj));
            } catch (Exception e) {
                continue;
            }

            Withdrawal withdrawal = withdrawalMapper.selectById(id);
            if (withdrawal == null) {
                continue;
            }

            String status = "skipped";
            String message = "状态不匹配";

            if ("approve".equalsIgnoreCase(action) && withdrawal.getStatus() == Withdrawal.StatusEnum.PENDING) {
                withdrawal.setStatus(Withdrawal.StatusEnum.APPROVED);
                withdrawal.setAuditAdminId(adminId);
                withdrawal.setAuditRemark(remark);
                withdrawal.setAuditTime(LocalDateTime.now());
                withdrawal.setUpdateTime(LocalDateTime.now());
                withdrawalMapper.updateById(withdrawal);
                status = "success";
                message = "审核通过";
            } else if ("reject".equalsIgnoreCase(action) && withdrawal.getStatus() == Withdrawal.StatusEnum.PENDING) {
                withdrawal.setStatus(Withdrawal.StatusEnum.REJECTED);
                withdrawal.setAuditAdminId(adminId);
                withdrawal.setAuditRemark(remark);
                withdrawal.setAuditTime(LocalDateTime.now());
                withdrawal.setUpdateTime(LocalDateTime.now());
                withdrawalMapper.updateById(withdrawal);
                status = "success";
                message = "审核拒绝";
            } else if ("pay".equalsIgnoreCase(action) && withdrawal.getStatus() == Withdrawal.StatusEnum.APPROVED) {
                withdrawal.setStatus(Withdrawal.StatusEnum.PAID);
                withdrawal.setAuditRemark(remark);
                withdrawal.setPayTime(LocalDateTime.now());
                withdrawal.setUpdateTime(LocalDateTime.now());
                withdrawalMapper.updateById(withdrawal);
                status = "success";
                message = "已打款";
            }

            Map<String, Object> row = new LinkedHashMap<>();
            row.put("id", id);
            row.put("status", status);
            row.put("message", message);
            results.add(row);
        }

        writeLog(adminId, "BATCH_WITHDRAW_AUDIT", "批量提现处理，action=" + action + "，count=" + results.size(), "/admin/withdraw/batch/audit", "POST");
        return Result.success(results);
    }
}
