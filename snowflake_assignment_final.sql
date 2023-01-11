------------------Task 1--------------------
--Creating the roles--
create role if not exists Admin;
create role if not exists Developer;
create role if not exists PII;

--Creating hierarchy--
grant role Developer to role Admin;
grant role Admin to role Accountadmin;
grant role PII to role Accountadmin;

--veiwing created roles--
show roles;
--------------------------------------------


------------------Task 2--------------------
--Creating a warehouse
create or replace warehouse assignment_wh with warehouse_size='MEDIUM';
--------------------------------------------


------------------Task 3--------------------
--granting create database and usage on warehouse to admin role before switching to it--
grant create database on account to role Admin;
grant usage on warehouse assignment_wh to role Admin;

--Switching to admin role--
use role Admin;
--------------------------------------------


------------------Task 4--------------------
--Creating a database--
create database if not exists assignment_db;
--------------------------------------------


------------------Task 5--------------------
--Creating a schema--
create schema if not exists my_schema;
--------------------------------------------


------------------Task 6--------------------
--Creating a table-- 
create or replace table employees_int (
	EMPLOYEE_ID int,
	FIRST_NAME string,
	LAST_NAME string,
	EMAIL string,
	PHONE_NUMBER string,
	HIRE_DATE date,
	JOB_ID string,
	SALARY string,
	MANAGER_ID int,
	DEPARTMENT_ID int,
    ELT_TS timestamp,
    FILE_NAME varchar,
    ELT_BY varchar
);

create or replace table employees_ext (
	EMPLOYEE_ID int,
	FIRST_NAME string,
	LAST_NAME string,
	EMAIL string,
	PHONE_NUMBER string,
	HIRE_DATE date,
	JOB_ID string,
	SALARY string,
	MANAGER_ID int,
	DEPARTMENT_ID int,
    ELT_TS timestamp,
    FILE_NAME varchar,
    ELT_BY varchar
);
--------------------------------------------


------------------Task 7--------------------
CREATE OR REPLACE TABLE employee_variant(
employee_id int,
name variant,
details variant
);

COPY INTO employee_variant
FROM (SELECT p.$1,to_variant(object_construct(p.$2,p.$3)),to_variant(object_construct(p.$4,p.$5,p.$6,p.$7)) FROM @my_internal_stage p)
file_format = (type = 'CSV' field_delimiter = ',' skip_header = 1);

select * from employee_variant;
--------------------------------------------


------------------Task 8--------------------
--creating an internal stage--
create or replace stage my_internal_stage
  file_format = (type = 'CSV' field_delimiter = ',' skip_header = 1);

--command on local ---put file:///Users/gnaneswarreddy/Documents/employees.csv @my_internal_stage; 

--listing the loaded files in stage--  
list @my_internal_stage;

--Switching to accountadmin role--
use role accountadmin

--granting create integration to admin role--
grant create integration on account to role admin;

--Switching to admin role--
use role Admin;

--creating the storage integration--
create or replace storage integration s3_ext
  type = external_stage
  storage_provider = s3
  enabled = true
  storage_aws_role_arn = 'arn:aws:iam::514940436571:role/snow_policy'
  storage_allowed_locations = ('s3://snowflake--assignment1/external_stage/');
  
--describing integration--
DESC INTEGRATION s3_ext;

--creating an external stage--
create or replace stage my_external_stage
    storage_integration=s3_ext
    url = 's3://snowflake--assignment1/external_stage/'
    file_format = (type = 'CSV' field_delimiter = ',' skip_header = 1);
    
--listing the loaded files in stage--
list @my_external_stage;
--------------------------------------------


------------------Task 9--------------------
--loading data into table from internal stage--
copy into employees_int from 
(select p.$1,p.$2,p.$3,p.$4,p.$5,p.$6,p.$7,p.$8,p.$9,p.$10,current_timestamp(),METADATA$FILENAME,'Local' from @my_internal_stage p)
file_format = (type = 'CSV' field_delimiter = ',' skip_header = 1);

--query to view data in table--
select * from employees_int;

--loading data into table from external stage--
copy into employees_ext from 
(select p.$1,p.$2,p.$3,p.$4,p.$5,p.$6,p.$7,p.$8,p.$9,p.$10,current_timestamp(),METADATA$FILENAME,'S3 Bucket' from @my_external_stage/employees.csv p)
file_format = (type = 'CSV' field_delimiter = ',' skip_header = 1);

--query to view data in table--
select * from employees_ext;

--------------------------------------------


------------------Task 10-------------------
--listing the files in stage to see uploaded parquet file--
list @my_external_stage;

--creating user defined file format for parquet type--
create or replace file format parquet type='PARQUET';

---query for displaying schema of parquet file using infer schema--
select *from table(
    infer_schema(
      location=>'@my_external_stage',
      file_format=>'parquet'
      )
    );
--------------------------------------------


------------------Task 11-------------------
--select query on the staged parquet file without loading it to table--
select * from @my_external_stage/userdata1.parquet(file_format => 'parquet');
--------------------------------------------


------------------Task 12-------------------
--creating a masking policy to user with developer role--
create or replace masking policy mask as (val string) returns string ->
  case
    when current_role() in ('DEVELOPER') then '**masked**'
    else val
  end;

--applying masking on email and phone_number columns of table--
alter table if exists employees_ext modify column email set masking policy mask;
alter table if exists employees_ext modify column phone_number set masking policy mask;

--granting access to view table employees_ext to all roles--
grant usage on database assignment_db to role public;
grant usage on schema my_schema to role public;
grant select on table employees_ext to role public;

--Switching to accountadmin role--
use role accountadmin

--granting usage on warehouse--
grant usage on warehouse assignment_wh to role public;

--Switching to developer role and checking whether cloumns are masked--
use role developer;
select * from employees_ext;

--Switching to pii role and checking whether cloumns are masked--
use role pii;
select * from employees_ext;
--------------------------------------------

