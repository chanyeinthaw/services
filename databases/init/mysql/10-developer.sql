-- Full-access development account for local and tailnet clients.
CREATE USER IF NOT EXISTS 'developer'@'%' IDENTIFIED BY 'dev-mysql';
ALTER USER 'developer'@'%' IDENTIFIED BY 'dev-mysql';
GRANT ALL PRIVILEGES ON *.* TO 'developer'@'%' WITH GRANT OPTION;
FLUSH PRIVILEGES;
