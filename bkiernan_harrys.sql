/*
1.  This file is to explain how I used sql to analyze the data set.  To begin,
    I used an open source program that I have on my local machine called DBeaver,
    found @ dbeaver.com.  Then, I have a sample vertica database running on a VM
    that I have used for other assessments and practice lessons on.

2.  Using excel, I broke apart the xlsx into two separate csv files, one for each
    sheet in the workbook.  Then, DBeaver has a tool that lets me export each
    csv into a table into the vertica db. Since each csv was unformatted, I used
    step 3 (below) to format the tables so that they read correctly.

3.  */
    --/* BEGIN FORMATTING FROM CSV LOAD */
    create table public.product_info1 as (
    	SELECT regexp_replace(viewable_product_id,'[^0-9]','')::int as viewable_product_id,
    		product::varchar(128) as product,
    		ltrim(price,'$')::numeric(20,2) as price,
    		regexp_replace(starter_set_count, '[^0-9]', '')::int as starter_set_count,
    		regexp_replace(other_set_count, '[^0-9]', '')::int as other_set_count,
    		regexp_replace(blade_count, '[^0-9]', '')::int as blade_count,
    		regexp_replace(handle_count, '[^0-9]', '')::int as handle_count,
    		regexp_replace(shave_gel_count, '[^0-9]', '')::int as shave_gel_count,
    		regexp_replace(shave_cream_count, '[^0-9]', '')::int as shave_cream_count,
    		regexp_replace(face_wash_count, '[^0-9]', '')::int as face_wash_count,
    		regexp_replace(aftershave_count, '[^0-9]', '')::int as aftershave_count,
    		regexp_replace(lipbalm_count, '[^0-9]', '')::int as lipbalm_count,
    		regexp_replace(razorstand_count, '[^0-9]', '')::int as razorstand_count,
    		regexp_replace(face_lotion_count, '[^0-9]', '')::int as face_lotion_count,
    		regexp_replace(travel_kit_count, '[^0-9]', '')::int as travel_kit_count
    	from public.product_info
    	ORDER BY 1
    );

    -- REPLACE INITIAL TABLE WITH FORMATTED TABLE
    drop table public.product_info;
    alter table public.product_info1 rename to product_info;
    --
    ---- FORMAT TABLE 2
    create table public.txn_data1 as (
    	SELECT sub_id::int as sub_id,
    		viewable_product_id::int as viewable_product_id,
    		created_at::timestamp as created_at,
    		quantity::int as quantity,
    		user_id::int as user_id,
    		case when removed_at = '' then null else removed_at::timestamp end as removed_at,
    		created_by_client_type,
    		case when removed_by_client_type = '' then null else removed_by_client_type end as removed_by_client_type
    	FROM public.txn_data
    );
    --
    ---- REPLACE INTIAL TABLE 2 WITH FORMATTED TABLE
    drop table public.txn_data;
    alter table public.txn_data1 rename to txn_data;
    --/* END FORMATTING */
/*

4.  Now that I have the two tables formatted, I can begin analysis:
*/
-- First, I want to just take a look at the breakdown of users by retention:
    with subscription_and_counts as (
     SELECT DISTINCT user_id,
       count(sub_id) as subscriptions,
       count(created_at) as created,
       count(removed_at) as removed
     FROM public.txn_data
     GROUP BY 1
     ORDER BY 1
    ) SELECT
       count(case when subscriptions > removed then user_id end) as retained_users,
       --^^ retained users = users that have at least 1 subscription not removed
       to_char(100*(count(case when subscriptions > removed then user_id end) / count(user_id)),'999.99%') as percent_retained,
       --^^ get percent of users that have at least 1 subscription not removed / total count of users
       count(case when subscriptions = removed then user_id end) as removed_users,
       --^^ removed users = users that have removed all of their subscriptions
       to_char(100*(count(case when subscriptions = removed then user_id end) / count(user_id)), '999.99%') as percent_removed,
       --^^ get percent of users that have removed all of their subscriptions
       count(user_id) as total_users
       --^^ total count of users
     FROM subscription_and_counts;

-- Now, I want to look at the types of products that have the most subscriptions vs
-- amount of removed subscriptions
    SELECT a.product,
    	sum(case when b.removed_at is null then b.quantity else 0 end) as active_subscriptions,
    	sum(case when b.removed_at is not null then b.quantity else 0 end) as removed_subscriptions
    FROM public.product_info a
    LEFT JOIN public.txn_data b
    	USING(viewable_product_id)
    GROUP BY 1
    ORDER BY 1;

-- further, I want to see the products from those removed
    with removed_users as (
    	SELECT DISTINCT user_id,
    		count(sub_id),
    		count(removed_at)
    	FROM public.txn_data
    	GROUP BY 1
    	HAVING count(sub_id) = count(removed_at)
    	ORDER BY 1
    ), removed as (
    	SELECT product,
    		sum(quantity) as subscriptions
    	FROM public.txn_data a
    	LEFT JOIN public.product_info b
    		USING(viewable_product_id)
    	WHERE a.user_id IN (SELECT user_id FROM removed_users)
    	GROUP BY 1
    	ORDER BY 1
    ), retained as (
    	SELECT product,
    		sum(quantity) as subscriptions
    	FROM public.txn_data a
    	LEFT JOIN public.product_info b
    		USING(viewable_product_id)
    	WHERE a.user_id NOT IN (SELECT user_id FROM removed_users)
    	GROUP BY 1
    	ORDER BY 1
    )
    	SELECT a.product,
    		a.subscriptions as retained_subscriptions,
    		b.subscriptions as removed_subscriptions
    	FROM retained a
    	LEFT JOIN removed b
    		USING(product);

-- Now, I want to look at the monthly performance:
    SELECT a.month,
    	a.retained_subscriptions,
    	coalesce(b.removed_subscriptions,0) as removed_subscriptions 
    FROM (
          SELECT date_trunc('month',created_at)::date as month, 
              sum(quantity) as retained_subscriptions 
          FROM public.txn_data 
          GROUP BY 1 
          ORDER BY 1
        ) a 
    LEFT JOIN (
          SELECT date_trunc('month',removed_at)::date as month, 
              sum(quantity) as removed_subscriptions 
          FROM public.txn_data 
          WHERE removed_at is not null 
          GROUP BY 1 
          ORDER BY 1
        ) b 
    	USING(month) 





















































/*
    TO USE BI Tools, I selected QlikView, which is very similar to Tableau
    and also because they have a free version, so I didn't need to have a license
    to use for this data
*/
--1. I used the below script to append a 'type' column to build and export an
--   xlsx to load into qlikview.

    drop table if exists test;
    create local temp table test on commit preserve rows as (
    with retained_users as (
    	SELECT DISTINCT user_id,
    		count(sub_id) as subscriptions,
    		count(removed_at) as removed
    	FROM public.txn_data
    	GROUP BY 1
    	HAVING count(sub_id) = count(removed_at)
    	ORDER BY 1
    ) SELECT *,
    	 'removed' as type
      FROM public.txn_data
      WHERE user_id IN (SELECT user_id FROM retained_users)
      UNION
      SELECT *,
      	 'retained' as type
      FROM public.txn_data
      WHERE user_id NOT IN (SELECT user_id FROM retained_users)
    );

    --- validate counts to ensure it's right:
    SELECT count(*)
    FROM test
    UNION ALL
    SELECT count(*)
    FROM public.txn_data
    -- returns 9,967 rows in both tables.
