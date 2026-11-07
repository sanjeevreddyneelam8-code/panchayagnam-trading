package com.py.repo;

import com.py.entity.PyAppSetting;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

@Repository
public interface PyAppSettingRepository extends JpaRepository<PyAppSetting, String> {
}
