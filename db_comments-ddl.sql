
CREATE USER db_comments IDENTIFIED BY "***********"
    DEFAULT TABLESPACE user_data
    TEMPORARY TABLESPACE temp
    ACCOUNT LOCK ;

grant UNLIMITED TABLESPACE TO db_comments ;
grant CREATE TABLE TO db_comments ;
grant CREATE VIEW TO db_comments ;
grant CREATE PROCEDURE TO db_comments ;
grant CREATE SESSION TO db_comments ;

------------------------------------------------------------------------

CREATE TABLE db_comments.object_type (
    obj_type_id integer not null,
    obj_type varchar2 ( 30 ) not null
    CONSTRAINT object_type_pk
        PRIMARY KEY ( obj_type_id )
    ) ;

COMMENT ON TABLE db_comments.object_type IS 'The list of the object types that may be commented on. Workaround for not being able to "COMMENT ON {role, schema, user, sequence, etc.} IS ..." in Oracle. Note that this list is not limited to the OBJECT_TYPEs found in views such as all_objects, neither does it contain all the OBJECT_TYPEs found in views such as all_objects.';

INSERT INTO db_comments.object_type ( obj_type_id, obj_type ) VALUES ( 1, 'DATABASE LINK' ) ;
INSERT INTO db_comments.object_type ( obj_type_id, obj_type ) VALUES ( 2, 'FUNCTION' ) ;
INSERT INTO db_comments.object_type ( obj_type_id, obj_type ) VALUES ( 3, 'INDEX' ) ;
INSERT INTO db_comments.object_type ( obj_type_id, obj_type ) VALUES ( 4, 'PACKAGE' ) ;
INSERT INTO db_comments.object_type ( obj_type_id, obj_type ) VALUES ( 5, 'PROCEDURE' ) ;
INSERT INTO db_comments.object_type ( obj_type_id, obj_type ) VALUES ( 6, 'PROFILE' ) ;
INSERT INTO db_comments.object_type ( obj_type_id, obj_type ) VALUES ( 7, 'ROLE' ) ;
INSERT INTO db_comments.object_type ( obj_type_id, obj_type ) VALUES ( 8, 'SCHEMA' ) ;
INSERT INTO db_comments.object_type ( obj_type_id, obj_type ) VALUES ( 9, 'SEQUENCE' ) ;
INSERT INTO db_comments.object_type ( obj_type_id, obj_type ) VALUES ( 10, 'SYNONYM' ) ;
INSERT INTO db_comments.object_type ( obj_type_id, obj_type ) VALUES ( 11, 'TYPE' ) ;
INSERT INTO db_comments.object_type ( obj_type_id, obj_type ) VALUES ( 12, 'USER' ) ;

COMMIT ;

------------------------------------------------------------------------

CREATE TABLE db_comments.database_comment (
    comments varchar2 ( 4000 )
    ) ;

COMMENT ON TABLE db_comments.database_comment IS 'Workaround for not being able to "COMMENT ON DATABASE <name> IS ..." in Oracle. Descriptive comment on the database ( why was it created, what purpose does it serve ) .';

------------------------------------------------------------------------

CREATE TABLE db_comments.global_object_comment (
    obj_type_id integer not null,
    object_name varchar2 ( 30 ) not null,
    comments varchar2 ( 4000 ),
    CONSTRAINT global_object_comment_pk
        PRIMARY KEY ( obj_type_id, object_name )
    ) ;

COMMENT ON TABLE db_comments.global_object_comment IS 'Comments on global ( a.k.a. non-schema ) objects. Workaround for not being able to "COMMENT ON {role, schema, user, etc.} <object_name> IS ..." in Oracle. Descriptive comment on the purpose for the specified object ( why was it created, what purpose does it serve ) .';

ALTER TABLE db_comments.global_object_comment
    ADD CONSTRAINT global_object_comment_fk
    FOREIGN KEY ( obj_type_id )
    REFERENCES db_comments.object_type ( obj_type_id ) ;

------------------------------------------------------------------------

CREATE TABLE db_comments.schema_object_comment (
    obj_type_id integer not null,
    schema_name varchar2 ( 30 ) not null,
    object_name varchar2 ( 30 ) not null,
    comments varchar2 ( 4000 ),
    CONSTRAINT schema_object_comment_pk
        PRIMARY KEY ( obj_type_id, schema_name, object_name )
    ) ;

COMMENT ON TABLE db_comments.schema_object_comment IS 'Consolidated view of schema object comments, incorporating db_comments data as well as all_tab_comments and all_mview_comments data';

ALTER TABLE db_comments.schema_object_comment
    ADD CONSTRAINT schema_object_comment_fk
    FOREIGN KEY ( obj_type_id )
    REFERENCES db_comments.object_type ( obj_type_id ) ;

------------------------------------------------------------------------

CREATE OR REPLACE VIEW db_comments.v_global_comment
AS
SELECT t.obj_type AS object_type,
        c.object_name,
        c.comments
    FROM db_comments.global_object_comment c
    JOIN db_comments.object_type t
        ON ( c.obj_type_id = t.obj_type_id ) ;

COMMENT ON TABLE db_comments.v_global_comment IS 'Global object comments from the db_comments data';

CREATE OR REPLACE VIEW db_comments.v_schema_comment
AS
SELECT t.obj_type AS object_type,
        c.schema_name,
        c.object_name,
        c.comments
    FROM db_comments.schema_object_comment c
    JOIN db_comments.object_type t
        ON ( c.obj_type_id = t.obj_type_id ) ;

COMMENT ON TABLE db_comments.v_schema_comment IS 'Schema object comments from the db_comments data';

CREATE OR REPLACE VIEW db_comments.v_all_schema_comment
AS
SELECT t.obj_type AS object_type,
        c.schema_name,
        c.object_name,
        c.comments
    FROM db_comments.schema_object_comment c
    JOIN db_comments.object_type t
        ON ( c.obj_type_id = t.obj_type_id )
UNION
SELECT a.table_type AS object_type,
        a.owner AS schema_name,
        a.table_name AS object_name,
        a.comments
    FROM all_tab_comments a
UNION
SELECT 'MATERIALIZED VIEW' AS object_type,
        a.owner AS schema_name,
        a.mview_name AS object_name,
        a.comments
    FROM all_mview_comments a ;

COMMENT ON TABLE db_comments.v_all_schema_comment IS 'Combined schema object comments from the db_comments data and Oracle comment metadata';

CREATE OR REPLACE PROCEDURE db_comments.comment_on_database (
    a_new_comment db_comments.database_comment.comments%type )
IS
BEGIN

    DELETE FROM db_comments.database_comment ;

    INSERT INTO db_comments.database_comment (
            comments )
        VALUES (
            a_new_comment ) ;

    COMMIT ;

END ;
/

CREATE OR REPLACE PROCEDURE db_comments.COMMENT_ON_DBLINK (
    a_schema_name db_comments.schema_object_comment.schema_name%type,
    a_object_name db_comments.schema_object_comment.object_name%type,
    a_new_comment db_comments.schema_object_comment.comments%type )
IS
BEGIN
    db_comments.comment_on_schema_object ( 'DATABASE LINK', a_schema_name, a_object_name, a_new_comment ) ;
END ;
/

CREATE OR REPLACE PROCEDURE db_comments.comment_on_function (
    a_schema_name db_comments.schema_object_comment.schema_name%type,
    a_object_name db_comments.schema_object_comment.object_name%type,
    a_new_comment db_comments.schema_object_comment.comments%type )
IS
BEGIN
    db_comments.comment_on_schema_object ( 'FUNCTION', a_schema_name, a_object_name, a_new_comment ) ;
END ;
/

CREATE OR REPLACE PROCEDURE db_comments.comment_on_global_object (
    a_obj_type db_comments.object_type.obj_type%type,
    a_object_name db_comments.global_object_comment.object_name%type,
    a_new_comment db_comments.global_object_comment.comments%type )
IS
BEGIN
DECLARE
type_id db_comments.object_type.obj_type_id%type ;
BEGIN

    SELECT obj_type_id
        INTO type_id
        FROM db_comments.object_type
        WHERE obj_type = a_obj_type ;

    IF type_id IS NOT NULL THEN

        DELETE FROM db_comments.global_object_comment
            WHERE obj_type_id = type_id
                AND object_name = a_object_name ;

        INSERT INTO db_comments.global_object_comment (
                obj_type_id,
                object_name,
                comments )
            VALUES (
                type_id,
                a_object_name,
                a_new_comment ) ;

        COMMIT ;

    END IF ;

END ;
END ;
/

CREATE OR REPLACE PROCEDURE db_comments.comment_on_index (
    a_schema_name db_comments.schema_object_comment.schema_name%type,
    a_object_name db_comments.schema_object_comment.object_name%type,
    a_new_comment db_comments.schema_object_comment.comments%type )
IS
BEGIN
    db_comments.comment_on_schema_object ( 'INDEX', a_schema_name, a_object_name, a_new_comment ) ;
END ;
/

CREATE OR REPLACE PROCEDURE db_comments.comment_on_package (
    a_schema_name db_comments.schema_object_comment.schema_name%type,
    a_object_name db_comments.schema_object_comment.object_name%type,
    a_new_comment db_comments.schema_object_comment.comments%type )
IS
BEGIN
    db_comments.comment_on_schema_object ( 'PACKAGE', a_schema_name, a_object_name, a_new_comment ) ;
END ;
/

CREATE OR REPLACE PROCEDURE db_comments.comment_on_procedure (
    a_schema_name db_comments.schema_object_comment.schema_name%type,
    a_object_name db_comments.schema_object_comment.object_name%type,
    a_new_comment db_comments.schema_object_comment.comments%type )
IS
BEGIN
    db_comments.comment_on_schema_object ( 'PROCEDURE', a_schema_name, a_object_name, a_new_comment ) ;
END ;
/

CREATE OR REPLACE PROCEDURE db_comments.comment_on_profile (
    a_object_name db_comments.global_object_comment.object_name%type,
    a_new_comment db_comments.global_object_comment.comments%type )
IS
BEGIN
    db_comments.comment_on_global_object ( 'PROFILE', a_object_name, a_new_comment ) ;
END ;
/

CREATE OR REPLACE PROCEDURE db_comments.comment_on_role (
    a_object_name db_comments.global_object_comment.object_name%type,
    a_new_comment db_comments.global_object_comment.comments%type )
IS
BEGIN
    db_comments.comment_on_global_object ( 'ROLE', a_object_name, a_new_comment ) ;
END ;
/

CREATE OR REPLACE PROCEDURE db_comments.comment_on_schema (
    a_object_name db_comments.global_object_comment.object_name%type,
    a_new_comment db_comments.global_object_comment.comments%type )
IS
BEGIN
    db_comments.comment_on_global_object ( 'SCHEMA', a_object_name, a_new_comment ) ;
END ;
/

CREATE OR REPLACE PROCEDURE db_comments.comment_on_schema_object (
    a_obj_type db_comments.object_type.obj_type%type,
    a_schema_name db_comments.schema_object_comment.schema_name%type,
    a_object_name db_comments.schema_object_comment.object_name%type,
    a_new_comment db_comments.schema_object_comment.comments%type )
IS
BEGIN
DECLARE
type_id db_comments.object_type.obj_type_id%type ;
BEGIN

    SELECT obj_type_id
        INTO type_id
        FROM db_comments.object_type
        WHERE obj_type = a_obj_type ;

    IF type_id IS NOT NULL THEN

        DELETE FROM db_comments.schema_object_comment
            WHERE obj_type_id = type_id
                AND schema_name = a_schema_name
                AND object_name = a_object_name ;

        INSERT INTO db_comments.schema_object_comment (
                obj_type_id,
                schema_name,
                object_name,
                comments )
            VALUES (
                type_id,
                a_schema_name,
                a_object_name,
                a_new_comment ) ;

        COMMIT ;

    END IF ;

END ;
END ;
/

CREATE OR REPLACE PROCEDURE db_comments.comment_on_sequence (
    a_schema_name db_comments.schema_object_comment.schema_name%type,
    a_object_name db_comments.schema_object_comment.object_name%type,
    a_new_comment db_comments.schema_object_comment.comments%type )
IS
BEGIN
    db_comments.comment_on_schema_object ( 'SEQUENCE', a_schema_name, a_object_name, a_new_comment ) ;
END ;
/

CREATE OR REPLACE PROCEDURE db_comments.comment_on_synonym (
    a_schema_name db_comments.schema_object_comment.schema_name%type,
    a_object_name db_comments.schema_object_comment.object_name%type,
    a_new_comment db_comments.schema_object_comment.comments%type )
IS
BEGIN
    db_comments.comment_on_schema_object ( 'SYNONYM', a_schema_name, a_object_name, a_new_comment ) ;
END ;
/

CREATE OR REPLACE PROCEDURE db_comments.comment_on_type (
    a_schema_name db_comments.schema_object_comment.schema_name%type,
    a_object_name db_comments.schema_object_comment.object_name%type,
    a_new_comment db_comments.schema_object_comment.comments%type )
IS
BEGIN
    db_comments.comment_on_schema_object ( 'TYPE', a_schema_name, a_object_name, a_new_comment ) ;
END ;
/

CREATE OR REPLACE PROCEDURE db_comments.comment_on_user (
    a_object_name db_comments.global_object_comment.object_name%type,
    a_new_comment db_comments.global_object_comment.comments%type )
IS
BEGIN
    db_comments.comment_on_global_object ( 'USER', a_object_name, a_new_comment ) ;
END ;
/

------------------------------------------------------------------------
CREATE ROLE db_commenter ;

GRANT EXECUTE ON db_comments.comment_on_database    TO db_commenter ;
GRANT EXECUTE ON db_comments.comment_on_dblink      TO db_commenter ;
GRANT EXECUTE ON db_comments.comment_on_function    TO db_commenter ;
GRANT EXECUTE ON db_comments.comment_on_index       TO db_commenter ;
GRANT EXECUTE ON db_comments.comment_on_package     TO db_commenter ;
GRANT EXECUTE ON db_comments.comment_on_procedure   TO db_commenter ;
GRANT EXECUTE ON db_comments.comment_on_profile     TO db_commenter ;
GRANT EXECUTE ON db_comments.comment_on_role        TO db_commenter ;
GRANT EXECUTE ON db_comments.comment_on_schema      TO db_commenter ;
GRANT EXECUTE ON db_comments.comment_on_sequence    TO db_commenter ;
GRANT EXECUTE ON db_comments.comment_on_synonym     TO db_commenter ;
GRANT EXECUTE ON db_comments.comment_on_type        TO db_commenter ;
GRANT EXECUTE ON db_comments.comment_on_user        TO db_commenter ;
GRANT SELECT ON db_comments.database_comment        TO db_commenter ;
GRANT SELECT ON db_comments.global_object_comment   TO db_commenter ;
GRANT SELECT ON db_comments.object_type             TO db_commenter ;
GRANT SELECT ON db_comments.schema_object_comment   TO db_commenter ;
GRANT SELECT ON db_comments.v_all_schema_comment    TO db_commenter ;
GRANT SELECT ON db_comments.v_global_comment        TO db_commenter ;
GRANT SELECT ON db_comments.v_schema_comment        TO db_commenter ;

CREATE ROLE db_comments_read ;

GRANT SELECT ON db_comments.database_comment        TO db_comments_read ;
GRANT SELECT ON db_comments.global_object_comment   TO db_comments_read ;
GRANT SELECT ON db_comments.object_type             TO db_comments_read ;
GRANT SELECT ON db_comments.schema_object_comment   TO db_comments_read ;
GRANT SELECT ON db_comments.v_all_schema_comment    TO db_comments_read ;
GRANT SELECT ON db_comments.v_global_comment        TO db_comments_read ;
GRANT SELECT ON db_comments.v_schema_comment        TO db_comments_read ;
