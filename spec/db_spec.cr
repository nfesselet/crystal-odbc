require "./spec_helper"
require "db/spec"

private class NotSupportedType
end

DB::DriverSpecs(DB::Any).run do |ctx|
  before do
    File.delete(DB_FILENAME) if File.exists?(DB_FILENAME)
  end
  after do
    File.delete(DB_FILENAME) if File.exists?(DB_FILENAME)
  end

  ctx.connection_string "#{DSN}#{DB_FILENAME}"

  sample_value true, "TINYINT", "1", type_safe_value: false
  sample_value false, "TINYINT", "0", type_safe_value: false
  sample_value 2, "int", "2", type_safe_value: false
  sample_value 1_i64, "int", "1"
  sample_value "hello", "text", "'hello'"
  sample_value 1.5_f32, "float", "1.5", type_safe_value: false
  sample_value 1.5, "float", "1.5"
  sample_value Time.utc(2020, 4, 5), "date", "'2020-04-05 00:00:00.000'", type_safe_value: false
  sample_value Time.utc(2020, 4, 5, 10, 15, 30), "datetime", "'2020-04-05 10:15:30.000'", type_safe_value: false

  binding_syntax do |_|
    "?"
  end

  create_table_1column_syntax do |table_name, col1|
    "create table #{table_name} (#{col1.name} #{col1.sql_type} #{col1.null ? "NULL" : "NOT NULL"})"
  end

  create_table_2columns_syntax do |table_name, col1, col2|
    "create table #{table_name} (#{col1.name} #{col1.sql_type} #{col1.null ? "NULL" : "NOT NULL"}, #{col2.name} #{col2.sql_type} #{col2.null ? "NULL" : "NOT NULL"})"
  end

  select_1column_syntax do |table_name, col1|
    "select #{col1.name} from #{table_name}"
  end

  select_2columns_syntax do |table_name, col1, col2|
    "select #{col1.name}, #{col2.name} from #{table_name}"
  end

  select_count_syntax do |table_name|
    "select count(*) from #{table_name}"
  end

  select_scalar_syntax do |expression, _|
    "select #{expression}"
  end

  insert_1column_syntax do |table_name, col, expression|
    "insert into #{table_name} (#{col.name}) values (#{expression})"
  end

  insert_2columns_syntax do |table_name, col1, expr1, col2, expr2|
    "insert into #{table_name} (#{col1.name}, #{col2.name}) values (#{expr1}, #{expr2})"
  end

  drop_table_if_exists_syntax do |table_name|
    "drop table if exists #{table_name}"
  end

  it "gets last insert row id", prepared: :both do |db|
    db.exec "create table person (name text, age integer)"
    db.exec %(insert into person values ("foo", 10))
    res = db.exec %(insert into person values ("foo", 10))
    res.last_insert_id.should eq(-1)
    res.rows_affected.should eq(1)
  end

  it "raises on unsupported param types" do |db|
    expect_raises ODBC::Error, "ODBC::Statement does not support NotSupportedType params" do
      db.query "select ?", NotSupportedType.new
    end
  end

  it "ensures statements are closed" do |db|
    db.exec %(create table if not exists a (i int not null, str text not null);)
    db.exec %(insert into a (i, str) values (23, "bai bai");)

    2.times do |i|
      DB.open ctx.connection_string do |db|
        begin
          db.query("SELECT i, str FROM a WHERE i = ?", 23) do |rs|
            rs.move_next
            break
          end
        rescue e : ODBC::Error
          fail("Expected no exception, but got \"#{e.message}\"")
        end

        begin
          db.exec("UPDATE a SET i = ? WHERE i = ?", 23, 23)
        rescue e : ODBC::Error
          fail("Expected no exception, but got \"#{e.message}\"")
        end
      end
    end
  end

  it "handles single-step pragma statements" do |db|
    db.exec %(PRAGMA synchronous = OFF)
  end

  it "handles multi-step pragma statements" do |db|
    db.exec %(PRAGMA journal_mode = memory)
  end
end
