CREATE OR REPLACE PROCEDURE DropTablesByPrefix(prefix text)
AS $$
DECLARE
    tbl_name text;
BEGIN
    -- Get the list of table names with the specified prefix
    FOR tbl_name IN SELECT table_name FROM information_schema.tables WHERE table_name ILIKE prefix || '%'
    LOOP
        EXECUTE 'DROP TABLE IF EXISTS ' || tbl_name || ' CASCADE;';
    END LOOP;
END;
$$ LANGUAGE plpgsql;

CALL DropTablesByPrefix('P2P');
CALL DropTablesByPrefix('Peers');
CALL DropTablesByPrefix('Friends');
CALL DropTablesByPrefix('RECOMM');
CALL DropTablesByPrefix('verter');

-- 2 --
CREATE OR REPLACE PROCEDURE GetScalarFunctionsWithArguments(
    OUT function_info TEXT,
    OUT function_count INTEGER
)
AS $$
BEGIN
    CREATE TEMPORARY TABLE temp_function_info (info TEXT);
    -- Insert function information into the temporary table
    INSERT INTO temp_function_info
    SELECT p.proname || ' (' || pg_catalog.pg_get_function_arguments(p.oid) || ')' AS info
    FROM pg_catalog.pg_proc p
    JOIN pg_catalog.pg_namespace n ON p.pronamespace = n.oid
    WHERE p.prokind = 'f'
        AND n.nspname = 'public'
        AND pg_catalog.pg_get_function_arguments(p.oid) <> '';
    SELECT COUNT(*) INTO function_count FROM temp_function_info;
    SELECT STRING_AGG(info, E'\n') INTO function_info FROM temp_function_info;

    DROP TABLE temp_function_info;
END;
$$ LANGUAGE plpgsql;

DO $$
DECLARE
    output_function_info TEXT;
    output_function_count INTEGER;
BEGIN
    CALL GetScalarFunctionsWithArguments(output_function_info, output_function_count);
    RAISE NOTICE 'Function Info: %', output_function_info;
    RAISE NOTICE 'Function Count: %', output_function_count;
END;
$$;

-- Tests for the 2nd Task --

CREATE OR REPLACE FUNCTION test_func_with_no_args()
RETURNS VOID AS $$
DECLARE
    function_list TEXT;
    function_count INT;
BEGIN
    RAISE NOTICE 'Calling test func without args...';
    CALL GetScalarFunctionsWithArguments(function_list, function_count);
    RAISE NOTICE 'Function Count: %', function_count;
    RAISE NOTICE 'Function List:%', function_list;
END;
$$ LANGUAGE plpgsql;

SELECT test_func_with_no_args();


CREATE OR REPLACE FUNCTION test_func_with_arguments(prefix text, other_parameter char)
RETURNS VOID AS $$
DECLARE
    function_list TEXT;
    function_count INT;
BEGIN
    RAISE NOTICE 'Calling test function...';
    CALL GetScalarFunctionsWithArguments(function_list, function_count);
    RAISE NOTICE 'Function Count: %', function_count;
    RAISE NOTICE 'Function List:%', function_list;
    RAISE NOTICE 'Prefix: %', prefix;
    RAISE NOTICE 'Other Parameter: %', other_parameter;
END;
$$ LANGUAGE plpgsql;

SELECT test_func_with_arguments('my_prefix', 'X');

CREATE OR REPLACE FUNCTION another_test_func_with_args(prefix text, limit_count int)
RETURNS VOID AS $$
DECLARE
    function_list TEXT;
    function_count INT;
BEGIN
    RAISE NOTICE 'Calling test function...';   
    CALL GetScalarFunctionsWithArguments(function_list, function_count);   
    RAISE NOTICE 'Function Count: %', function_count;
    RAISE NOTICE 'Function List (up to % functions): %', limit_count, LEFT(function_list, limit_count);
    RAISE NOTICE 'Prefix: %', prefix;
    RAISE NOTICE 'Limit Count: %', limit_count;
END;
$$ LANGUAGE plpgsql;

SELECT another_test_func_with_args('test_prefix', 3);


CREATE OR REPLACE FUNCTION test_func_with_three_args(a INT, b INT, c INT) RETURNS INT AS $$
BEGIN
    RETURN a * b + c;
END;
$$ LANGUAGE plpgsql;

SELECT test_func_with_three_args(5, 2, 7);

-- 3 --

CREATE OR REPLACE PROCEDURE DestroyAllTriggers(
    OUT destroyed_trigger_count INTEGER
)
AS $$
DECLARE
    trigger_record RECORD;
BEGIN
    destroyed_trigger_count := 0;

    FOR trigger_record IN
        SELECT tgname, tgrelid::regclass
        FROM pg_trigger
        WHERE tgconstraint = 0
    LOOP
        EXECUTE 'DROP TRIGGER ' || trigger_record.tgname || ' ON ' || trigger_record.tgrelid || ' CASCADE';
        destroyed_trigger_count := destroyed_trigger_count + 1;
    END LOOP;
END;
$$ LANGUAGE plpgsql;

DO $$
DECLARE
    output_destroyed_trigger_count INTEGER;
BEGIN
    CALL DestroyAllTriggers(output_destroyed_trigger_count);
    RAISE NOTICE 'Destroyed Trigger Count: %', output_destroyed_trigger_count;
END;
$$;

-- To see all triggers before deleting
SELECT tgname, tgrelid::regclass, tgtype, tgdeferrable, tginitdeferred
FROM pg_trigger -- all system triggers
WHERE NOT tgisinternal; -- only user-defined triggers

-- Tests for the 3rd Task --

-- Create a table for the test
CREATE TABLE test_table (
    id serial PRIMARY KEY,
    name text
);

-- Create a test trigger that sets a timestamp on insert
CREATE OR REPLACE FUNCTION set_created_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.created_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_set_created_at
BEFORE INSERT ON test_table
FOR EACH ROW
EXECUTE FUNCTION set_created_at();

-- Create a test trigger that updates a modified timestamp on update
CREATE OR REPLACE FUNCTION set_modified_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.modified_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_set_modified_at
BEFORE UPDATE ON test_table
FOR EACH ROW
EXECUTE FUNCTION set_modified_at();

-- 4 --

CREATE OR REPLACE PROCEDURE SearchObjectTypesByString(
    IN search_string TEXT,
    OUT object_info TEXT
)
AS $$
DECLARE
    result_record RECORD;
BEGIN
    object_info := '';
    -- Search for stored procedures and scalar functions in the public schema
    FOR result_record IN
        SELECT proname, obj_description(p.oid, 'pg_proc') AS object_description, 
               CASE WHEN p.prokind = 'p' THEN 'PROCEDURE' ELSE 'FUNCTION' END AS object_type
        FROM pg_proc p
        JOIN pg_namespace n ON p.pronamespace = n.oid
        WHERE n.nspname = 'public'
            AND p.proname ILIKE '%' || search_string || '%'
            AND p.prokind IN ('p', 'f')
    LOOP
        object_info := object_info || result_record.object_type || ': ' || result_record.proname || E'\n';
    END LOOP;
    IF object_info = '' THEN
        object_info := 'No matching objects found.';
    END IF;
END;
$$ LANGUAGE plpgsql;

-- Tests for the 4th Task --

-- Search for func and proc with name 'test' on it
DO $$
DECLARE
    search_result TEXT;
BEGIN
    CALL SearchObjectTypesByString('test', search_result);
    RAISE NOTICE 'Search Result:%', search_result;
END;
$$;

-- No matching objects
DO $$
DECLARE
    search_result TEXT;
BEGIN
    CALL SearchObjectTypesByString('1', search_result);
    RAISE NOTICE 'Search Result:%', search_result;
END;
$$;

-- create funcs and procs for test
CREATE OR REPLACE FUNCTION test_function(input_val INT)
RETURNS INT AS $$
BEGIN
    RETURN input_val * 2;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION Second_test_function(a INT, b INT)
RETURNS INT
AS $$
BEGIN
    RETURN a + b;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE PROCEDURE SearchObject_Test()
AS $$
DECLARE
    search_result TEXT;
BEGIN
    CALL SearchObjectTypesByString('test', search_result);
    RAISE NOTICE 'Search Result:%', search_result;
END;
$$ LANGUAGE plpgsql;

CALL SearchObject_Test();

