create or replace procedure import_from_csv (table_name text, path text, delim char(1) default ',')
as $$
begin
execute 'COPY '||$1||' FROM ''D:\s21_projects\SQL2_Info21_v1.0-2\src\data\'||$2||''' DELIMITER '''||$3||''' CSV header';
end;
$$ language plpgsql;

create or replace procedure export_to_csv (table_name text, path text, delim char(1) default ',')
as $$
begin
	execute 'COPY '||$1||' TO ''D:\s21_projects\SQL2_Info21_v1.0-2\src\data\'||$2||''' DELIMITER '''||$3||''' CSV HEADER';
end;
$$ language plpgsql;