# PostgreSQL Database Creator

A robust shell script for creating PostgreSQL databases with proper security configuration, including users, roles, and permissions.

## Features

- 🚀 **Automated Database Setup**: Creates databases with optimized security configuration
- 🔐 **Secure User Management**: Creates application and owner users with appropriate permissions
- 🎭 **Role-Based Access**: Implements read-write and creator roles with proper privilege separation
- 🔑 **Auto-Generated Passwords**: Generates secure passwords automatically
- ✅ **Pre-flight Validation**: Checks for existing databases/users and validates configuration
- 🛡️ **Error Handling**: Comprehensive error checking with colored output
- 📝 **Credential Management**: Optional credential file generation
- ⚙️ **Flexible Configuration**: Dynamic configuration via external file
- 🌐 **Load Balancer Testing**: Optional connectivity testing via load balancer

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
```

### Optional Configuration

```bash
# PostgreSQL Password (optional, will be prompted if not provided)
PG_PASSWORD="your_postgres_password"

# Custom User Passwords (optional, auto-generated if not provided)
USER_APP_PASSWORD="custom_app_password"
USER_OWNER_PASSWORD="custom_owner_password"

# Save credentials to file after creation
SAVE_CREDENTIALS_FILE="credentials.txt"

# Load Balancer Testing (Optional)
ENABLE_LB_TEST="true"                 # Set to "true" to enable LB testing

# Load Balancer Connection Settings (required if ENABLE_LB_TEST="true")
LB_HOST="your-loadbalancer-host.com"  # Load balancer hostname/IP
LB_PORT="5432"                        # Load balancer port
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

### Save Credentials to File

Add this to your config file:

```bash
SAVE_CREDENTIALS_FILE="my_database_credentials.txt"
```

After running, you'll get a file like:
```
# Database Credentials - 2024-01-15 14:30:25
Database: myapp_db
Host: localhost
Port: 5432

Application User: myapp_app
Application Password: xK9mP2vR8nQ4wE7y

Owner User: myapp_owner
Owner Password: aJ5hG1sL6dF3pZ9t
```

## Command Line Options

```bash
./create_db.sh [config_file]  # Use specified config file
./create_db.sh --help         # Show help message
```

## Load Balancer Testing

The script includes optional connectivity testing to verify that the created database is accessible via a load balancer.

### Enabling Load Balancer Testing

Add these settings to your configuration file:

```bash
# Enable load balancer testing
ENABLE_LB_TEST="true"

# Load balancer connection details
LB_HOST="your-loadbalancer.example.com"
LB_PORT="5432"
```

### What Gets Tested

When enabled, the script will test connectivity for both users:

1. **Owner User Connection**: Verifies the owner can connect via load balancer
2. **Application User Connection**: Verifies the app user can connect via load balancer

### Test Results

- ✅ **Success**: Both users can connect via the load balancer
- ❌ **Failure**: Script exits with error if either user cannot connect

### Use Cases

- Verify load balancer configuration after database setup
- Ensure network connectivity between application and database
- Validate that database users are properly configured for remote access
- Test database failover scenarios

## Error Handling

The script includes comprehensive error checking:

- ✅ PostgreSQL server connectivity
- ✅ Configuration validation
- ✅ Database name format validation
- ✅ Username format validation
- ✅ Duplicate database detection
- ✅ Duplicate user detection
- ✅ SQL execution success/failure
- ✅ Load balancer connectivity (when enabled)

## Security Considerations

- 🔒 Auto-generated passwords are 25 characters long using base64 encoding
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

5. **"Load balancer connection failed"**
   - Verify load balancer is running and accessible
   - Check LB_HOST and LB_PORT in configuration
   - Ensure load balancer is properly configured to route to PostgreSQL
   - Verify network connectivity between script host and load balancer
   - Check if load balancer health checks are passing

6. **"Connectivity tests failed"**
   - Ensure database users have proper host-based authentication
   - Check pg_hba.conf configuration for load balancer IP range
   - Verify load balancer SSL/TLS configuration matches PostgreSQL
   - Test connection manually with psql from script host

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