CREATE DATABASE IF NOT EXISTS fitnesstracker;




CREATE TABLE IF NOT EXISTS trackerdata(
    Id VARCHAR(30) NOT NULL PRIMARY KEY,
    date DATETIME NOT NULL,
    TotalSteps INT NOT NULL,
    TotalDistance DECIMAL(10,2) NOT NULL,
    TrackerDistance DECIMAL(10,2) NOT NULL,
    LoggedActivitiesDistance DECIMAL(20,20) NOT NULL,
    VeryActiveDistance DECIMAL(10,2) NOT NULL,
    ModeratelyActiveDistance DECIMAL(10,2) NOT NULL,
    LightActiveDistance DECIMAL(10,2) NOT NULL,
    SedentaryActiveDistance DECIMAL(10,2) NOT NULL,
    VeryActiveMinutes INT NOT NULL,
    FairlyActiveMinutes INT NOT NULL,
    LightlyActiveMinutes INT NOT NULL,
    SedentaryMinutes INT NOT NULL,
    Calories INT NOT NULL
);

ALTER TABLE trackerdata
RENAME COLUMN  date TO ActivityDate;

-- Daily summary of activity for each user--------------------------------------------------------------

SELECT 
    Id AS user_id,
    ActivityDate AS date,
    TotalSteps AS steps,
    TotalDistance AS distance_covered,
    SedentaryMinutes AS sedentary_time,
    VeryActiveMinutes + FairlyActiveMinutes + LightlyActiveMinutes AS active_time,
    Calories AS calories_burned
FROM 
    trackerdata
ORDER BY 
    user_id, date;

-- Weekly aggregate of activity metrics-----------------------------------------------------------------

SELECT 
    Id AS user_id,
    STR_TO_DATE(CONCAT(YEAR(ActivityDate), ' ', WEEK(ActivityDate, 1), ' Monday'), '%Y %u %W') AS week_start,
    SUM(TotalSteps) AS weekly_steps,
    SUM(TotalDistance) AS weekly_distance,
    SUM(VeryActiveMinutes + FairlyActiveMinutes + LightlyActiveMinutes) AS weekly_active_minutes,
    SUM(SedentaryMinutes) AS weekly_sedentary_minutes,
    SUM(Calories) AS weekly_calories_burned
FROM 
    trackerdata
GROUP BY 
    user_id, week_start
ORDER BY 
    user_id, week_start
LIMIT 1000;


-- Monthly aggregate of activity metrics----------------------------------------------------------------

SELECT 
    Id AS user_id,
    DATE_TRUNC('month', ActivityDate) AS month_start,
    SUM(TotalSteps) AS monthly_steps,
    SUM(TotalDistance) AS monthly_distance,
    SUM(VeryActiveMinutes + FairlyActiveMinutes + LightlyActiveMinutes) AS monthly_active_minutes,
    SUM(SedentaryMinutes) AS monthly_sedentary_minutes,
    SUM(Calories) AS monthly_calories_burned
FROM 
    trackerdata
GROUP BY 
    user_id, month_start
ORDER BY 
    user_id, month_start;

-- Top 10 users by total steps in a specific period

SELECT 
    user_id,
    SUM(steps) AS total_steps
FROM 
    (SELECT 
         Id AS user_id, 
         ActivityDate AS date, 
         TotalSteps AS steps
     FROM 
         dailyActivity_merged_cleaned) AS activity_data
GROUP BY 
    user_id
ORDER BY 
    total_steps DESC
LIMIT 10;

-- Bottom 10 least active users by total steps

SELECT 
    user_id,
    SUM(steps) AS total_steps
FROM 
    (SELECT 
         Id AS user_id, 
         ActivityDate AS date, 
         TotalSteps AS steps
     FROM 
         dailyActivity_merged_cleaned) AS activity_data
GROUP BY 
    user_id
ORDER BY 
    total_steps ASC
LIMIT 10;

-- Activity time by time of day

SELECT 
    Id AS user_id,
    EXTRACT(HOUR FROM ActivityDate) AS hour_of_day,
    SUM(TotalSteps) AS total_steps
FROM 
    trackerdata
GROUP BY 
    user_id, hour_of_day
ORDER BY 
    hour_of_day, total_steps DESC;



-- Trend of daily steps over time for each user

WITH daily_activity AS (
    SELECT 
        Id AS user_id,
        ActivityDate AS date,
        SUM(TotalSteps) AS daily_steps
    FROM 
        trackerdata
    GROUP BY 
        user_id, date
)
SELECT 
    user_id,
    date,
    daily_steps,
    LAG(daily_steps, 1) OVER (PARTITION BY user_id ORDER BY date) AS previous_day_steps,
    daily_steps - LAG(daily_steps, 1) OVER (PARTITION BY user_id ORDER BY date) AS steps_change
FROM 
    daily_activity
ORDER BY 
    user_id, date;

-- Trend of calories burned over time for each user

SELECT 
    user_id,
    date,
    calories_burned,
    LAG(calories_burned, 1) OVER (PARTITION BY user_id ORDER BY date) AS previous_day_calories,
    calories_burned - LAG(calories_burned, 1) OVER (PARTITION BY user_id ORDER BY date) AS calories_change
FROM 
    (SELECT 
         Id AS user_id, 
         ActivityDate AS date, 
         Calories AS calories_burned
     FROM 
         trackerdata) AS calorie_data
ORDER BY 
    user_id, date;
    
-- User Activity Clustering ----------------------------------------------------------------------------

WITH activity_summary AS (
    SELECT 
        Id AS user_id,
        AVG(TotalSteps) AS avg_daily_steps,
        AVG(VeryActiveMinutes + FairlyActiveMinutes + LightlyActiveMinutes) AS avg_daily_active_minutes
    FROM 
        trackerdata
    GROUP BY 
        user_id
)
SELECT 
    user_id,
    avg_daily_steps,
    avg_daily_active_minutes,
    CASE 
        WHEN avg_daily_steps >= 15000 AND avg_daily_active_minutes >= 180 THEN 'Highly Active'
        WHEN avg_daily_steps BETWEEN 8000 AND 14999 AND avg_daily_active_minutes BETWEEN 60 AND 179 THEN 'Moderately Active'
        ELSE 'Low Activity'
    END AS activity_level
FROM 
    activity_summary
ORDER BY 
    activity_level DESC;
    
-- Creating a View for Dashboard -------------------------------------------------------------------------------------

CREATE VIEW UserActivitySummary AS
SELECT 
    Id AS user_id,
    ActivityDate AS date,
    TotalSteps AS total_steps,
    TotalDistance AS total_distance,
    VeryActiveMinutes + FairlyActiveMinutes + LightlyActiveMinutes AS active_minutes,
    SedentaryMinutes AS sedentary_minutes,
    Calories AS calories_burned,
    DATE_SUB(ActivityDate, INTERVAL WEEKDAY(ActivityDate) DAY) AS week_start,  -- Start of the week
    DATE_FORMAT(ActivityDate, '%Y-%m-01') AS month_start                       -- Start of the month
FROM 
    trackerdata;
