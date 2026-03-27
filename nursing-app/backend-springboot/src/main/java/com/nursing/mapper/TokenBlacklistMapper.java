package com.nursing.mapper;

import com.baomidou.mybatisplus.core.mapper.BaseMapper;
import com.nursing.entity.TokenBlacklist;
import org.apache.ibatis.annotations.Mapper;
import org.apache.ibatis.annotations.Param;
import org.apache.ibatis.annotations.Select;

@Mapper
public interface TokenBlacklistMapper extends BaseMapper<TokenBlacklist> {

    @Select("SELECT COUNT(*) FROM token_blacklist WHERE token = #{token} AND expire_time > NOW()")
    int countByToken(@Param("token") String token);
}
