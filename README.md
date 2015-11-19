# oracle-comments

Oracle comments is a simple schema the entire purpose of which is to
provide a place to store comments on various kinds Oracle objects/items
directly in the oracle database (beyond the table/view/materialized view
comments that Oracle supports).

Comments can be made on the following object/item types:

* DATABASE LINK
* FUNCTION
* INDEX
* PACKAGE
* PROCEDURE
* PROFILE
* ROLE
* SCHEMA
* SEQUENCE
* SYNONYM
* TYPE
* USER

For each kind of thing there is a procedure, in the form of
comment_on_x ( ... ), for maintaining the comments on that kind of
thing. For example, the comment_on_role (role_name, role_comment)
procedure supports commenting on roles.

This was inspired by the ability in PostgreSQL to comment on pretty
much everything and the annoyance of not being able to do that in Oracle.
