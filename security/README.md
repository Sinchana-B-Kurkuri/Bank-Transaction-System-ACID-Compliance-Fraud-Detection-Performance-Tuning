# Role-based access control setup

Run `01_roles_and_grants.sql` manually as a DBA after the views have been installed.
The script targets the database name `bank_txn`; replace that qualifier if your target
database has a different name. It creates roles and grants access to views rather than
granting application roles direct access to base tables.

Before granting a role to an application login:
1. Create a dedicated MySQL login with a strong secret outside this repository.
2. Add a row to `DB_User_Map` for the exact login name (or the host-independent login).
3. Grant only the required role to that login and set it as the default role.
4. Test with that login that the customer views return only mapped rows and that direct
   SELECTs from base tables are denied.
5. Keep DBA/admin credentials separate from application credentials.

The script deliberately does not create users, store passwords, grant roles to all users,
or run automatically as part of rebuild. MySQL roles are database-level privileges; verify
your production account and host naming rules before deployment.
