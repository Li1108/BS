package com.nursing.mapper;

import com.baomidou.mybatisplus.core.mapper.BaseMapper;
import com.nursing.entity.SysUser;
import org.apache.ibatis.annotations.Mapper;
import org.apache.ibatis.annotations.Param;
import org.apache.ibatis.annotations.Select;

@Mapper
public interface SysUserMapper extends BaseMapper<SysUser> {

    /**
     * 根据手机号查找用户
     */
    @Select("SELECT * FROM user_account WHERE phone = #{phone}")
    SysUser findByPhone(@Param("phone") String phone);

    /**
     * 查询用户角色编码
     */
    @Select("SELECT r.role_code FROM user_role ur JOIN role r ON ur.role_id = r.id WHERE ur.user_id = #{userId} LIMIT 1")
    String findRoleCodeByUserId(@Param("userId") Long userId);

    @Select("SELECT COUNT(1) FROM user_role ur JOIN role r ON ur.role_id = r.id WHERE ur.user_id = #{userId} AND r.role_code = #{roleCode}")
    int countUserRole(@Param("userId") Long userId, @Param("roleCode") String roleCode);
}
