package com.bidly.category.repository;

import com.bidly.category.entity.Category;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.UUID;

@Repository
public interface CategoryRepository extends JpaRepository<Category, UUID> {

    /** Top-level categories (no parent). */
    @Query("SELECT c FROM Category c WHERE c.parent IS NULL AND c.active = true ORDER BY c.sortOrder ASC")
    List<Category> findTopLevelCategories();

    /** Find category by exact name. */
    java.util.Optional<Category> findByName(String name);

    /** Find category by case-insensitive name. */
    java.util.Optional<Category> findFirstByNameIgnoreCase(String name);

    /** Subcategories for a given parent. */
    List<Category> findByParentIdAndActiveTrueOrderBySortOrderAsc(UUID parentId);
}
