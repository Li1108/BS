package com.nursing.mapper;

import com.baomidou.mybatisplus.core.mapper.BaseMapper;
import com.nursing.entity.SysConfig;
import org.apache.ibatis.annotations.Mapper;
import org.apache.ibatis.annotations.Param;
import org.apache.ibatis.annotations.Select;

@Mapper
public interface SysConfigMapper extends BaseMapper<SysConfig> {

    @Select("SELECT config_value FROM system_config WHERE config_key = #{key}")
    String getValueByKey(@Param("key") String key);
}
