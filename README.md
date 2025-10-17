# PostgreSQL Database Creator

A robust shell script for creating PostgreSQL databases with proper security configuration, including users, roles, and permissions.

## Features

- 🚀 **Automated Database Setup**: Creates databases with optimized security configuration
- 🔐 **Secure User Management**: Creates application and owner users with appropriate permissions
- 🎭 **Role-Based Access**: Implements read-write and creator roles with proper privilege separation
- 🔑 **Auto-Generated Passwords**: Generates secure passwords automatically
- ✅ **Pre-flight Validation**: Checks for existing databases/users and validates configuration
- 🛡️ **Error Handling**: Comprehensive error checking with colored output
- 📝 **Credential Management**: Automatic credential file saving with date format
- ⚙️ **Flexible Configuration**: Dynamic configuration via external file
- 🌐 **Connectivity Testing**: Mandatory app and owner user testing via load balancer or direct instance

## Quick Start

### Prerequisites

- PostgreSQL server running and accessible
- `psql` command-line client installed
- Sufficient privileges to create databases and users (typically postgres superuser)

### Installation

1. Clone or download the script files
2. Make the script executable:
   ```bash
   chmod +x create_db.sh
   ```

### Basic Usage

1. **Create configuration file:**
   ```bash
   cp db_config.conf.example db_config.conf
   ```

2. **Edit the configuration:**
   ```bash
   nano db_config.conf  # or your preferred editor
   ```

3. **Run the script:**
   ```bash
   ./create_db.sh
   ```

## Configuration

### Required Configuration Variables

Edit `db_config.conf` with the following variables:

```bash
# Database Configuration
DBNAME="myapp_db"                    # Your database name

# Usernames
USER_APP="myapp_app"                 # Application user (read-write access)
USER_OWNER="myapp_owner"             # Database owner (full access)

# Role Names
ROLE_RW="myapp_readwrite"            # Read-write role
ROLE_RC="myapp_creator"              # Creator role

# PostgreSQL Connection
PG_USER="postgres"                   # PostgreSQL admin user
PG_HOST="localhost"                  # PostgreSQL host
PG_PORT="5432"                       # PostgreSQL port

# Connection Testing (Mandatory)
TEST_HOST="localhost"                # Test host - can be load balancer IP or direct instance IP
TEST_PORT="5432"                     # Test port
```

### Optional Configuration

```bash
# PostgreSQL Password (optional, will be prompted if not provided)
PG_PASSWORD="your_postgres_password"

# Custom User Passwords (optional, auto-generated if not provided)
USER_APP_PASSWORD="custom_app_password"
USER_OWNER_PASSWORD="custom_owner_password"

# Optional: Custom credential file name (overrides auto-generated filename)
# SAVE_CREDENTIALS_FILE="my_custom_credentials.txt"
```

## Database Schema and Permissions

The script creates the following database structure:

### Users Created

1. **Application User** (`$USER_APP`):
   - Belongs to the read-write role
   - Can SELECT, INSERT, UPDATE, DELETE on all tables
   - Can use sequences
   - Ideal for application connections

2. **Owner User** (`$USER_OWNER`):
   - Belongs to the creator role
   - Full database access including DDL operations
   - Can create tables, indexes, functions
   - Ideal for database migrations and admin tasks

### Roles Created

1. **Read-Write Role** (`$ROLE_RW`):
   - CONNECT on database
   - USAGE on schema
   - SELECT, INSERT, UPDATE, DELETE on all tables
   - USAGE on sequences
   - EXECUTE on functions

2. **Creator Role** (`$ROLE_RC`):
   - CONNECT on database
   - USAGE and CREATE on schema
   - Full table permissions
   - TEMPORARY table creation
   - CREATE on database

### Security Features

- Public access revoked from database and schema
- Default privileges set for future objects
- Proper search path configuration
- Secure random password generation

## Usage Examples

### Basic Database Creation

```bash
# Use default configuration file
./create_db.sh

# Use custom configuration file
./create_db.sh production_db.conf
```

### With Custom Passwords

Set passwords in your config file:

```bash
USER_APP_PASSWORD="MySecureAppPassword123!"
USER_OWNER_PASSWORD="MySecureOwnerPassword456!"
```

### Automatic Credential Saving

When passwords are auto-generated, credentials are automatically saved to a file with the format:
```
cred_{DBNAME}_{DDMMYYYY}.txt
```

For example: `cred_myapp_db_15012024.txt`

The credential file contains:
```
# Database Credentials - Mon Jan 15 14:30:25 UTC 2024
Database: myapp_db
Host: localhost
Port: 5432

Application User: myapp_app
Application Password: xK9mP2vR8nQ4wE7y

Owner User: myapp_owner
Owner Password: aJ5hG1sL6dF3pZ9t
```

### Custom Credential File Name (Optional)

If you prefer a custom filename, add this to your config file:

```bash
SAVE_CREDENTIALS_FILE="my_database_credentials.txt"
```

This will override the automatic filename generation.

## Command Line Options

```bash
./create_db.sh [config_file]  # Use specified config file
./create_db.sh --help         # Show help message
```

## Connectivity Testing

The script includes mandatory connectivity testing to verify that the created database is accessible. The test can be performed via either a load balancer or direct instance connection.

### Configuring Connectivity Testing

Add these settings to your configuration file:

```bash
# Connection Testing (Mandatory)
TEST_HOST="your-loadbalancer.example.com"    # Can be load balancer IP or direct instance IP
TEST_PORT="5432"
```

### What Gets Tested

The script tests connectivity for both users:

1. **Application User Connection (Mandatory)**: Verifies the app user can connect via the specified host

2. **Owner User Connection (Mandatory)**: Verifies the owner can connect via the specified host

### Test Results

- ✅ **Success**: Both application user and owner user can connect
- ❌ **Failure**: Script exits with error if either user cannot connect

### Use Cases

- Verify database accessibility after setup
- Test connectivity via load balancer or direct instance
- Ensure network connectivity between application and database
- Validate that database users are properly configured for remote access
- Test database failover scenarios by testing different endpoints

## Error Handling

The script includes comprehensive error checking:

- ✅ PostgreSQL server connectivity
- ✅ Configuration validation
- ✅ Database name format validation
- ✅ Username format validation
- ✅ Duplicate database detection
- ✅ Duplicate user detection
- ✅ SQL execution success/failure
- ✅ Connectivity testing (mandatory for both app and owner users)

## Security Considerations

- 🔒 Auto-generated passwords are 16 characters long using base64 encoding
- 🔒 Public database and schema privileges are revoked
- 🔒 Principle of least privilege applied to user roles
- 🔒 Credentials are only written to file if explicitly requested
- 🔒 Configuration files should be protected with appropriate file permissions

## Troubleshooting

### Common Issues

1. **"PostgreSQL is not running"**
   - Ensure PostgreSQL server is started
   - Check connection parameters in config

2. **"Permission denied"**
   - Ensure the `$PG_USER` has sufficient privileges
   - Check if PostgreSQL password is correct

3. **"Database already exists"**
   - Choose a different database name
   - Or drop the existing database manually

4. **"User already exists"**
   - Choose different usernames
   - Or drop existing users manually

5. **"Connectivity tests failed"**
   - Verify TEST_HOST and TEST_PORT are correct and accessible
   - Ensure database users have proper host-based authentication
   - Check pg_hba.conf configuration for the test host IP range
   - Test connection manually with psql from script host:
     - `psql -h TEST_HOST -p TEST_PORT -U USER_APP -d DBNAME`
     - `psql -h TEST_HOST -p TEST_PORT -U USER_OWNER -d DBNAME`
   - If using load balancer, verify it's properly configured to route to PostgreSQL
   - Check network connectivity and firewall rules between script host and test host

### Debug Mode

For detailed debugging, you can modify the script to enable `set -x` at the top.

## File Structure

```
.
├── create_db.sh              # Main executable script
├── db_config.conf.example    # Configuration template
├── db_config.conf           # Your configuration (create from example)
└── README.md                # This file
```

## License

This project is provided as-is for database administration purposes. Use at your own risk and ensure you have proper backups before running database creation scripts.