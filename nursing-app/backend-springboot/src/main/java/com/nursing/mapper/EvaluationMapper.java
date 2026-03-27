package com.nursing.mapper;

import com.baomidou.mybatisplus.core.mapper.BaseMapper;
import com.nursing.entity.Evaluation;
import org.apache.ibatis.annotations.Mapper;
import org.apache.ibatis.annotations.Param;
import org.apache.ibatis.annotations.Select;

@Mapper
public interface EvaluationMapper extends BaseMapper<Evaluation> {

	@Select("SELECT COUNT(1) FROM evaluation WHERE nurse_user_id = #{nurseUserId}")
	Long countByNurseUserId(@Param("nurseUserId") Long nurseUserId);

	@Select("SELECT AVG(rating) FROM evaluation WHERE nurse_user_id = #{nurseUserId}")
	Double avgRatingByNurseUserId(@Param("nurseUserId") Long nurseUserId);
}
