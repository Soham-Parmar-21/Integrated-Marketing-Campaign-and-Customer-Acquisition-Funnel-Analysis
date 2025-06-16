-- To check the count of rows imported
SELECT COUNT(*) FROM campaigns;
SELECT COUNT(*) FROM transactions;
SELECT COUNT(*) FROM user_journey;

SELECT * FROM campaigns;
SELECT * FROM transactions;
SELECT * FROM user_journey;


-- Check null values in user_jouney
SET SQL_SAFE_UPDATES = 0;

UPDATE user_journey
SET click_timestamp = NULL
WHERE click_timestamp = '';
ALTER TABLE user_journey
MODIFY COLUMN click_timestamp DATETIME;

UPDATE user_journey
SET signup_date = NULL
WHERE signup_date = '';
ALTER TABLE user_journey
MODIFY COLUMN signup_date DATETIME;


SELECT COUNT(*) as total_users,
	COUNT(click_timestamp) as users_clicked,
    COUNT(signup_date) as users_signed_up
FROM user_journey;


-- Check for negative/zero amount in transactions;
SELECT COUNT(*) FROM transactions WHERE amount <= 0;


-- User journeys by channels
SELECT c.channel , 
	COUNT(u.user_id) as total_users,
    COUNT(u.click_timestamp) as users_clicked,
    COUNT(u.signup_date) as users_signed_up
FROM user_journey u join campaigns c 
ON u.campaign_id = c.campaign_id
GROUP BY c.channel;


-- Day-wise Signup Trend
SELECT DATE(signup_date), COUNT(*) as daily_signup_count
FROM user_journey
WHERE signup_date IS NOT NULL
GROUP BY DATE(signup_date) 
ORDER BY daily_signup_count DESC;


-- Cumulative Signus Over Dates
SELECT DATE(signup_date), 
	COUNT(*) as daily_signups,
	SUM(COUNT(*)) OVER (ORDER BY DATE(signup_date)) as cumulative_signup_sum
FROM user_journey
WHERE signup_date IS NOT NULL
GROUP BY DATE(signup_date);


-- Channel Wise Revenue & Conversions
SELECT c.channel, 
	COUNT(DISTINCT u.user_id) as conversions, 
    ROUND(SUM(t.amount),2) as revenue
FROM user_journey u JOIN campaigns c 
ON u.campaign_id = c.campaign_id
JOIN transactions t
ON u.user_id = t.user_id
GROUP BY c.channel;


-- Count of clicks by hour
SELECT HOUR(click_timestamp) as click_hour,
	COUNT(*) as click_count
FROM user_journey
WHERE HOUR(click_timestamp) IS NOT NULL 
GROUP BY click_hour
ORDER BY click_count DESC;


-- User Funnel Status
SELECT user_id, campaign_id,
	CASE 
      WHEN signup_date IS NOT NULL THEN "Signed up"
      WHEN click_timestamp IS NOT NULL THEN "Only clicked"
      ELSE "Saw Only"
	END AS "user_funnel_status"
FROM user_journey;


-- Rank Users by Revenue
SELECT u.user_id, amount,
	RANK() OVER (ORDER BY amount DESC) As revenue_rank
FROM user_journey u join transactions t
ON u.user_id = t.user_id;


-- Time Between Click And Signup
SELECT user_id, click_timestamp, signup_date,
	TIMEDIFF(click_timestamp, signup_date)
FROM user_journey
WHERE click_timestamp IS NOT NULL AND signup_date IS NOT NULL;


-- Funnel Drop Off Categorization
SELECT c.channel, COUNT(*) as total_users,
     SUM(CASE WHEN u.click_timestamp IS NOT NULL THEN 1 ELSE 0 END) AS clicked,
     SUM(CASE WHEN u.signup_date IS NOT NULL THEN 1 ELSE 0 END) AS signed_up,
     SUM(CASE WHEN t.user_id IS NOT NULL THEN 1 ELSE 0 END) AS converted
FROM campaigns c JOIN user_journey u 
ON c.campaign_id = u.campaign_id
LEFT JOIN transactions t 
ON u.user_id = t.user_id
GROUP BY c.channel;


-- Conversion Lag Per Campaign
WITH signed AS (
SELECT u.user_id,
	c.campaign_id,
    c.channel,
    DATEDIFF(t.transaction_date, u.signup_date) as conversion_lag
FROM user_journey u JOIN campaigns c
ON u.campaign_id = c.campaign_id
LEFT JOIN transactions t 
ON u.user_id = t.user_id
)
SELECT channel, 
	AVG(conversion_lag) AS average_days_to_convert,
   MAX(conversion_lag) AS max_days_to_convert
FROM signed
GROUP BY channel;
  
  
-- Channels with Above Average CTR
With req_cte as (
SELECT 
    c.channel,
    COUNT(*) AS impressions,
    COUNT(u.click_timestamp) AS clicks
  FROM user_journey u
  JOIN campaigns c ON u.campaign_id = c.campaign_id
  GROUP BY c.channel
)
SELECT channel, clicks , impressions,
	ROUND((clicks * 100.0)/impressions, 2) as ctr_percent
FROM req_cte 
WHERE ROUND((clicks * 100.0)/impressions, 2) > (
	SELECT AVG((clicks * 100.0)/impressions) 
	FROM (SELECT channel, COUNT(*) AS impressions,
          COUNT(click_timestamp) AS clicks FROM user_journey u JOIN campaigns c
    ON u.campaign_id = c.campaign_id GROUP BY channel)as average_sub);
    
SELECT AVG((clicks * 100.0)/impressions) 
	FROM (SELECT channel, COUNT(*) AS impressions,
          COUNT(click_timestamp) AS clicks FROM user_journey u JOIN campaigns c
    ON u.campaign_id = c.campaign_id GROUP BY channel)as average_sub;
    

-- Campaign Efficiency Score
SELECT 
  c.campaign_id,
  c.channel,
  COUNT(DISTINCT u.user_id) AS impressions,
  COUNT(DISTINCT u.signup_date) AS signups,
  ROUND(SUM(t.amount), 2) AS revenue,
  ROUND(c.spend / NULLIF(COUNT(DISTINCT t.user_id), 0), 2) AS CAC,
  ROUND((SUM(t.amount) - c.spend) / NULLIF(c.spend, 0), 2) AS ROI,
  CASE 
    WHEN SUM(t.amount) > c.spend THEN 'Efficient'
    ELSE 'Inefficient'
  END AS campaign_efficiency
FROM user_journey u
JOIN campaigns c ON u.campaign_id = c.campaign_id
LEFT JOIN transactions t ON u.user_id = t.user_id
GROUP BY c.campaign_id, c.channel, c.spend;

