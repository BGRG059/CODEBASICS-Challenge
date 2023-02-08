###################################################################
#			SOLUTIONS TO CODEBASICS CHALLENGE #4				###
###################################################################

# CTE. Subqueries. DISTINCT. INNER JOIN (3 tables). GROUP BY. ORDER BY. SUBSTR. 
# Date functions: MONTH(), MONTHNAME(), YEAR().
# CASE STATEMENTS. ROW_NUMBER(). OVER( PARTITION BY ORDER BY).
# AGGREGATE FUNCTION: SUM() AVG() COUNT(). 

# 1. Provide the list of markets in which customer "Atliq Exclusive" operates its business in the APAC region.
## distinct statement was added because some of the markets have been duplicated/repeated. why is this? investigate!!
SELECT 	distinct(market) FROM dim_customer
WHERE 	customer = 'Atliq Exclusive'
AND 	region = 'APAC';
#===================================================================================================================
# 2.	What is the percentage of unique product increase in 2021 vs. 2020? The final output contains these fields.
## THIS SOLUTION USES THE "PRODUCT_CODE" COLUMN
WITH											
	a AS 											
    (												
    SELECT	COUNT(DISTINCT(product_code)) AS unique_products_2020			
		FROM	fact_manufacturing_cost						
		WHERE	cost_year = 2020 #245						
     ),  											
     b AS											
     (											
		SELECT	COUNT(DISTINCT(product_code)) AS  unique_products_2021	
		FROM	fact_manufacturing_cost						
		WHERE	cost_year = 2021						
     )											
SELECT	unique_products_2020,								
		unique_products_2021,								
        ROUND((((unique_products_2021 - unique_products_2020)/unique_products_2020)*100)) AS percentage_chg									
FROM	a join b;
## THIS SOLUTION USES THE "PRODUCT" COLUMN
WITH											
	a AS 											
    (												
		SELECT	COUNT(DISTINCT(product)) AS unique_products_2020 
		FROM	dim_product dm LEFT JOIN fact_gross_price gp
		ON		dm.product_code = gp.product_code
		WHERE	fiscal_year = 2020			
     ),  											
     b AS											
     (											
		SELECT	COUNT(DISTINCT(product)) AS unique_products_2021
		FROM	dim_product dm LEFT JOIN fact_gross_price gp
		ON		dm.product_code = gp.product_code
		WHERE	fiscal_year = 2021				
     )											
SELECT	unique_products_2020,								
		unique_products_2021,								
        ROUND((((unique_products_2021 - unique_products_2020)/unique_products_2020)*100)) AS percentage_chg									
FROM	a JOIN b;
#===================================================================================================================
# 3.	Provide a report with all the unique product counts for each segment and sort them in descending order of product counts
## DO WE USE PRODUCT OR PRODUCT_CODE COLUMN????

SELECT		segment, COUNT(product) AS product_count		
FROM		dim_product						
GROUP BY	segment						
ORDER BY 	product_count DESC;
#===================================================================================================================
# 4.	Follow-up: Which segment had the most increase in unique products in 2021 vs 2020? The final output contains these fields. Segment, product_count.

# THIS USES THE "PRODUCT" COLUMN.
WITH
	a  AS
    (
		SELECT		segment, COUNT(DISTINCT(dm.product)) AS product_count_2021
		FROM		dim_product dm LEFT JOIN fact_gross_price gp
		ON			dm.product_code = gp.product_code
		WHERE 		fiscal_year = 2021
        GROUP BY 	segment
	),
	b  AS
    ( 
		SELECT		segment, COUNT(DISTINCT(dm.product)) AS product_count_2020
		FROM		dim_product dm LEFT JOIN fact_gross_price gp
		ON			dm.product_code = gp.product_code
		WHERE		fiscal_year = 2020
        GROUP BY	segment
	)
SELECT		a.segment, product_count_2021, product_count_2020, 
			(product_count_2021 - product_count_2020) AS Difference
FROM 		a left JOIN b
ON 			a.segment = b.segment
ORDER BY	difference DESC;	
#===================================================================================================================
# 5. Get the products that have the highest and lowest manufacturing costs. The final output should contain these fields: product_code, product, manufacturing_cost

## CAN WE ADD A COLUMN THAT COMMENTS ON WHETHER THE manufacturing_cost IS HIGH OR LOW?
SELECT	mc.product_code, product, manufacturing_cost
FROM	fact_manufacturing_cost mc JOIN dim_product dm
ON		mc.product_code = dm.product_code
WHERE	manufacturing_cost 
IN		(
		 (SELECT max(manufacturing_cost) FROM fact_manufacturing_cost),
		 (SELECT min(manufacturing_cost) FROM fact_manufacturing_cost)
		);
#===================================================================================================================
# 6. Generate a report which contains the top 5 customers who received an average high pre_invoice_discount_pct for the fiscal year 2021 and in the Indian market.
##   The final output contains these fields: customer_code, customer, average_discount_percentage.
SELECT		a.customer, a.customer_code,
			Round(avg(b.pre_invoice_discount_pct),2) AS Avg_discount_pct
FROM		dim_customer a INNER JOIN fact_pre_invoice_deductions b
ON			a.customer_code = b.customer_code
WHERE		a.market = 'India'
AND 		fiscal_year = '2021'
GROUP BY	a.customer, a.customer_code
ORDER BY	avg_discount_pct DESC
LIMIT		5;

#===================================================================================================================
# 7.	Get the complete report of the Gross sales amount for the customer “Atliq Exclusive” for each month. This analysis helps to get an idea of low and high-performing months and take strategic decisions.
## The final report contains these columns: Month, Year, Gross sales Amount.

## COMMENT: Is it possible to display the gross sales amount table in units? Yes, use concat().
SELECT		CONCAT(substr(monthname(date),1,3), '. ', year(date)) AS 'Month',
			fsm.fiscal_year,
			CONCAT(Round((sum(sold_quantity) * sum(gross_price))/1000000000,2), ' bn.') AS gross_sales_amount
FROM		fact_sales_monthly fsm
JOIN		dim_customer dmc
ON			fsm.customer_code = dmc.customer_code
JOIN		fact_gross_price fgp
ON			fsm.product_code = fgp.product_code
WHERE		customer = 'atliq exclusive'
GROUP BY	date, fsm.fiscal_year
ORDER BY	date;

#===================================================================================================================

# 8. In which quarter of 2020, got the maximum total_sold_quantity?
## The final output contains these fields sorted by the total_sold_quantity: Quarter, total_sold_quantity
WITH 
cte AS
	(
	SELECT (CASE WHEN MONTH(date) IN (9,10,11) THEN 1
				 WHEN MONTH(date) IN (12,01,02) THEN 2
				 WHEN MONTH(date) IN (03,04,05)THEN 3
				 ELSE 4 
                 END) as Quarter,
				date
	FROM		(SELECT distinct(date)
				FROM fact_sales_monthly
				WHERE fiscal_year = 2020) d
	)
SELECT		quarter,
			concat(round(sum(sold_quantity)/1000000,2), ' M') Tot_sold_quantity
FROM		cte JOIN fact_sales_monthly fsm on cte.date = fsm.date
GROUP BY	quarter
ORDER BY	Tot_sold_quantity DESC;

#===================================================================================================================
# 9. Which channel helped to bring more gross sales in the fiscal year 2021 and the percentage of contribution?
## The final output contains these fields: channel, gross_sales_mln, percentage

WITH
cte AS
	(
	SELECT		channel,
				ROUND((sum(gross_price * sold_quantity)/1000000000),2) Gross_sales
	FROM		fact_gross_price fgp
				JOIN fact_sales_monthly fsm
				ON			fgp.product_code = fsm.product_code
                AND			fgp.fiscal_year = fsm.fiscal_year
				JOIN dim_customer dmc
				ON			dmc.customer_code = fsm.customer_code
	WHERE		fsm.fiscal_year = 2021
	GROUP BY channel
    )
SELECT 		channel,
			concat(gross_sales, ' bn.') Gross_sales,
            round((gross_sales/(sum(gross_sales) over())*100),2) AS '% of gross sales'
FROM		cte
ORDER BY	gross_sales desc
;

#===================================================================================================================
# 10. Get the Top 3 products in each division that have a high total_sold_quantity in the fiscal_year 2021?
## The final output contains these fields: division, product_code, product, total_sold_quantity, rank_order
WITH 
cte AS
	(
		SELECT		row_number() over(partition by division order by sum(sold_quantity) desc) AS Rank_order,
					division, fsm.product_code, product, sum(sold_quantity) tot_sold_quant
		FROM		fact_sales_monthly fsm
		INNER JOIN	dim_product dmp
		ON			fsm.product_code = dmp.product_code
		WHERE		fiscal_year = '2021'
		GROUP BY	division, fsm.product_code, product
	)
SELECT	rank_order, division, product, product_code,
		CONCAT(ROUND((tot_sold_quant/1000),2), ' K') AS 'Tot. Sold Quantity'
FROM	cte
WHERE	rank_order <= 3
;



#===================================================================================================================
# The following query returns product_codes which are not repeated in the fact_gross_price table.
# Not sure what purpose it serves but keeping it for future use.
# Thanks to username: 'Ohan' from CodeBasics discord for help.
SELECT	product_code, fiscal_year
FROM	fact_gross_price
WHERE	product_code 
IN		(SELECT product_code
		FROM fact_gross_price
		GROUP BY product_code
		HAVING COUNT(*) = 1
        );
#===================================================================================================================
