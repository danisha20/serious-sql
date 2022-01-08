-- Tasks: 
-- category_name: The name of the top 2 ranking categories
-- rental_count: How many total films have they watched in this category
-- average_comparison: How many more films has the customer watched compared to the average DVD Rental Co customer?
-- percentile: How does the customer rank in terms of the top X% compared to all other customers in this film category?
-- category_percentage: What proportion of total films watched does this category make up?



DROP TABLE IF EXISTS complete_joint_dataset;
CREATE TEMP TABLE complete_joint_dataset AS
SELECT
  rental.customer_id,
  inventory.film_id,
  film.title,
  rental.rental_date,
  category.name AS category_name
FROM dvd_rentals.rental
INNER JOIN dvd_rentals.inventory
  ON rental.inventory_id = inventory.inventory_id
INNER JOIN dvd_rentals.film
  ON inventory.film_id = film.film_id
INNER JOIN dvd_rentals.film_category
  ON film.film_id = film_category.film_id
INNER JOIN dvd_rentals.category
  ON film_category.category_id = category.category_id;

SELECT * FROM complete_joint_dataset limit 10;



-- rental_count: How many total films have they watched in this category
DROP TABLE IF EXISTS count_rental;
CREATE TEMP TABLE count_rental AS
WITH customer_cte AS (SELECT 
					  customer_id, category_name, rental_count, category_rank
FROM (SELECT customer_id, 
	category_name, 
	COUNT(*) AS rental_count,
	RANK() OVER (PARTITION BY customer_id ORDER BY COUNT(*) DESC) AS category_rank,
	MAX(rental_date) AS latest_rental_date 
FROM complete_joint_dataset
GROUP BY customer_id, category_name 
ORDER BY customer_id, rental_count DESC, latest_rental_date DESC) as temp)
SELECT  *
FROM customer_cte;

SELECT  *
FROM count_rental
WHERE category_rank < 3;

-- average_comparison: How many more films has the customer watched compared to the average DVD Rental Co customer
SELECT *, ABS(rental_count - (SELECT ROUND(AVG(rental_count),0)
FROM count_rental)) AS average_comparison 
FROM count_rental;


-- category_percentage: What proportion of total films watched 
--does this category make up?
DROP TABLE IF EXISTS average_category_count ;
CREATE TEMP TABLE average_category_count AS
	SELECT category_name, AVG(rental_count) as avg_rental_count
		FROM count_rental
		GROUP BY category_name;
UPDATE average_category_count
SET avg_rental_count = FLOOR(avg_rental_count)
RETURNING * ;


DROP TABLE IF EXISTS total_rent_count ;
CREATE TEMP TABLE total_rent_count AS
	SELECT SUM(rental_count) as total_rents
		FROM count_rental
		GROUP BY customer_id;


-- percentile: How does the customer rank in terms of the top X% 
--compared to all other customers in this film category?

DROP TABLE IF EXISTS percent_rank_cat;
CREATE TEMP TABLE percent_rank_cat AS
	SELECT *, CEILING(100*PERCENT_RANK() 
					 OVER(PARTITION BY category_name ORDER BY rental_count DESC))
					 AS percentile
	FROM count_rental;

--Joining tables
DROP TABLE IF EXISTS customer_join_table;
CREATE TEMP TABLE customer_join_table AS 
	SELECT
	t1.customer_id,
	t1.category_name,
	t1.rental_count,
	t1.category_rank,
	t2.total_rents,
	t3.avg_rental_count,
	t4.percentile,
	t1.rental_count - t3.avg_rental_count AS average_comparison,
	ROUND(100*t1.rental_count/t2.total_rents) AS category_percentage
	FROM count_rental as t1
	INNER JOIN total_rent_count as t2
		ON t1.customer_id = t2.customer_id
	INNER JOIN average_category_count as t3
		ON t1.category_name = t3.category_name
	INNER JOIN percent_rank_cat as t4 
	ON t1.category_name = t4.category_name AND t1.customer_id = t4.customer_id;

-- category_name: The name of the top 2 ranking categories per customer
SELECT * FROM customer_join_table
WHERE category_rank < 3
ORDER BY customer_id,category_rank;
	
	
