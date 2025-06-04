USE bi_challenge;

CREATE TABLE restaurants_visitors (
    id VARCHAR(20),
	visit_date DATE,
    visit_datetime DATETIME,
    reserve_datetime DATETIME,
    reserve_visitors INT
);

CREATE TABLE date_info (
    calendar_date DATE,
    day_of_week VARCHAR(20),
    holiday_flg TINYINT
);

CREATE TABLE store_info (
    store_id VARCHAR(255),
    genre_name VARCHAR(255),
    area_name VARCHAR(255),
    latitude DECIMAL(10, 7),
    longitude DECIMAL(10, 7)
);


LOAD DATA INFILE 'C:/ProgramData/MySQL/MySQL Server 8.4/Uploads/restaurants_visitors_limpio.csv'
INTO TABLE restaurants_visitors
FIELDS TERMINATED BY ',' 
ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS;

LOAD DATA INFILE 'C:/ProgramData/MySQL/MySQL Server 8.4/Uploads/store_info.csv'
INTO TABLE store_info
FIELDS TERMINATED BY ',' 
ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS;

-- Looking for NULL Values

SELECT
  COUNT(*) AS total_rows,
  COUNT(*) - COUNT(id) AS null_id,
  COUNT(*) - COUNT(visit_date) AS null_visit_date,
  COUNT(*) - COUNT(visit_datetime) AS null_visit_datetime,
  COUNT(*) - COUNT(reserve_datetime) AS null_reserve_datetime,
  COUNT(*) - COUNT(reserve_visitors) AS null_reserve_visitors
FROM restaurants_visitors;

SELECT
  COUNT(*) AS total_rows,
  COUNT(*) - COUNT(store_id) AS null_store_id,
  COUNT(*) - COUNT(genre_name) AS null_genre_name,
  COUNT(*) - COUNT(area_name) AS null_area_name,
  COUNT(*) - COUNT(latitude) AS null_latitude,
  COUNT(*) - COUNT(longitude) AS null_longitude
FROM store_info;

SELECT
  COUNT(*) AS total_rows,
  COUNT(*) - COUNT(calendar_date) AS null_calendar_date,
  COUNT(*) - COUNT(day_of_week) AS null_day_of_week,
  COUNT(*) - COUNT(holiday_flg) AS null_holiday_flg
FROM date_info;


-- Filling NULL values in restaurants_visitors

CREATE TABLE restaurants_visits_filled AS
SELECT
    id,
    DATE(visit_datetime) AS visit_date,
    visit_datetime,
    reserve_datetime,
    reserve_visitors
FROM restaurants_visitors;


-- TOP 5 restaurants by id in Holidays

WITH TotalByDay AS(
    SELECT
		id,
		visit_date,
        sum(reserve_visitors) as total_visitors_day
    FROM restaurants_visits_filled rv LEFT JOIN date_info di
    ON rv.visit_date = di.calendar_date
    WHERE holiday_flg = 1
    GROUP BY id, visit_date
),

Ranking AS(
	SELECT
		id,
		ROUND(AVG(total_visitors_day),0) AS avg_visitors,
		DENSE_RANK() OVER(ORDER BY AVG(total_visitors_day) DESC) AS restaurants_ranking
	FROM TotalByDay
	GROUP BY id
)

SELECT 
	id,
    genre_name,
    avg_visitors,
    restaurants_ranking
FROM Ranking r
INNER JOIN store_info si ON r.id = si.store_id
WHERE restaurants_ranking BETWEEN 1 AND 5
ORDER BY restaurants_ranking;



-- TOP 5 restaurants by genre in Holidays

WITH TotalByDay AS(
    SELECT
		genre_name,
		visit_date,
        sum(reserve_visitors) as total_visitors_day
    FROM restaurants_visits_filled rv 
    LEFT JOIN date_info di ON rv.visit_date = di.calendar_date
    LEFT JOIN store_info si ON rv.id = si.store_id
    WHERE holiday_flg = 1
    GROUP BY genre_name, visit_date
),

Ranking AS(
	SELECT
		genre_name,
		ROUND(AVG(total_visitors_day),0) AS avg_visitors,
		DENSE_RANK() OVER(ORDER BY AVG(total_visitors_day) DESC) AS genre_ranking
	FROM TotalByDay
	GROUP BY genre_name
)

SELECT *
FROM totalbyday
Order by Genre_name;


-- Best Day Overall
WITH RestDay AS(
    SELECT
        visit_date,
        day_of_week,
		ROUND(SUM(reserve_visitors),1) AS avg_visitors
    FROM restaurants_visits_filled rv 
    LEFT JOIN date_info di ON rv.visit_date = di.calendar_date
    LEFT JOIN store_info si ON rv.id = si.store_id
    GROUP BY visit_date, day_of_week
)

SELECT 
	day_of_week,
    avg(avg_visitors) as avg_visitors
FROM RestDay
GROUP BY day_of_week
ORDER BY avg(avg_visitors) DESC;

-- Best day by Genre

WITH RestDay AS(
    SELECT
		genre_name,
        visit_date,
        day_of_week,
		ROUND(SUM(reserve_visitors),1) AS total_visitors
    FROM restaurants_visits_filled rv 
    LEFT JOIN date_info di ON rv.visit_date = di.calendar_date
    LEFT JOIN store_info si ON rv.id = si.store_id
    GROUP BY genre_name, visit_date, day_of_week
),

Ranking AS (
	SELECT 
		genre_name,
        day_of_week,
        ROUND(AVG(total_visitors),0) AS avg_visitors,
		DENSE_RANK() OVER(PARTITION BY genre_name ORDER BY AVG(total_visitors) DESC) as day_rank
	FROM RestDay
    GROUP BY genre_name, day_of_week
)

SELECT 
	genre_name,
    day_of_week,
    avg_visitors
FROM Ranking;




-- WoW total
WITH RestDay AS(
    SELECT
        visit_date,
        YEAR(visit_date) as year,
        WEEK(visit_date) AS week_num,
		ROUND(SUM(reserve_visitors),1) AS total_visitors
    FROM restaurants_visits_filled rv 
    LEFT JOIN date_info di ON rv.visit_date = di.calendar_date
    LEFT JOIN store_info si ON rv.id = si.store_id
    GROUP BY visit_date, day_of_week
    HAVING YEAR(visit_date) = 2017
)

SELECT 
    week_num,
    SUM(total_visitors) AS visitors,
    LAG(SUM(total_visitors), 1) OVER(ORDER BY week_num) as next_week,
    (SUM(total_visitors) / LAG(SUM(total_visitors), 1) OVER(ORDER BY week_num)) - 1 AS WoW_change
FROM RestDay
GROUP BY week_num
HAVING week_num >= 19;


-- WoW By Genre
WITH RestDay AS(
    SELECT
		genre_name,
        visit_date,
        YEAR(visit_date) as year,
        WEEK(visit_date) AS week_num,
		ROUND(SUM(reserve_visitors),1) AS total_visitors
    FROM restaurants_visits_filled rv 
    LEFT JOIN date_info di ON rv.visit_date = di.calendar_date
    LEFT JOIN store_info si ON rv.id = si.store_id
    GROUP BY genre_name, visit_date, day_of_week
    HAVING YEAR(visit_date) = 2017
)

SELECT 
	genre_name,
    week_num,
    SUM(total_visitors),
    LAG(SUM(total_visitors), 1) OVER(PARTITION BY genre_name ORDER BY week_num) as next_week
FROM RestDay
GROUP BY genre_name, week_num
HAVING week_num >= 19
ORDER BY genre_name;

-- Visual Trend
WITH TotalByDay AS(
    SELECT
		visit_date,
        sum(reserve_visitors) as total_visitors_day
    FROM restaurants_visits_filled rv 
    LEFT JOIN date_info di ON rv.visit_date = di.calendar_date
    LEFT JOIN store_info si ON rv.id = si.store_id
    GROUP BY visit_date
)

SELECT * FROM TotalByDay
ORDER BY visit_date;