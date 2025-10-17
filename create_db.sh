#!/bin/bash

# PostgreSQL Database Creation Script
# Usage: ./create_db.sh [config_file]
# Default config file: db_config.conf

set -e

# Configuration file path
CONFIG_FILE="${1:-db_config.conf}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print colored output
print_error() {
    echo -e "${RED}ERROR: $1${NC}" >&2
}

print_success() {
    echo -e "${GREEN}SUCCESS: $1${NC}"
}

print_info() {
    echo -e "${YELLOW}INFO: $1${NC}"
}

# Function to check if PostgreSQL is running
check_postgres() {
    if ! pg_isready -q; then
        print_error "PostgreSQL is not running"
        exit 1
    fi
}

# Function to validate configuration
validate_config() {
    local required_vars=("DBNAME" "USER_APP" "USER_OWNER" "ROLE_RW" "ROLE_RC" "PG_USER" "PG_HOST" "PG_PORT")

    for var in "${required_vars[@]}"; do
        if [[ -z "${!var}" ]]; then
            print_error "Variable $var is not set in configuration file"
            exit 1
        fi
    done

    # Validate database name format
    if [[ ! "$DBNAME" =~ ^[a-zA-Z][a-zA-Z0-9_]*$ ]]; then
        print_error "Invalid database name: $DBNAME. Must start with letter and contain only letters, numbers, and underscores"
        exit 1
    fi

    # Validate user names format
    for user in "$USER_APP" "$USER_OWNER"; do
        if [[ ! "$user" =~ ^[a-zA-Z][a-zA-Z0-9_]*$ ]]; then
            print_error "Invalid user name: $user. Must start with letter and contain only letters, numbers, and underscores"
            exit 1
        fi
    done

    # Validate load balancer configuration if enabled
    if [[ "$ENABLE_LB_TEST" == "true" ]]; then
        if [[ -z "$LB_HOST" || -z "$LB_PORT" ]]; then
            print_error "Load balancer test is enabled but LB_HOST or LB_PORT is not configured"
            exit 1
        fi
    fi
}

# Function to load configuration
load_config() {
    if [[ ! -f "$CONFIG_FILE" ]]; then
        print_error "Configuration file '$CONFIG_FILE' not found"
        print_info "Create a configuration file based on the example template"
        exit 1
    fi

    # Source the configuration file
    source "$CONFIG_FILE"

    # Validate loaded configuration
    validate_config

    print_info "Configuration loaded from: $CONFIG_FILE"
}

# Function to generate random passwords
generate_password() {
    openssl rand -base64 32 | tr -d "=+/" | cut -c1-25
}

# Function to check if database exists
check_database_exists() {
    psql -h "$PG_HOST" -p "$PG_PORT" -U "$PG_USER" -d postgres -tAc "SELECT 1 FROM pg_database WHERE datname='$DBNAME'" | grep -q 1
}

# Function to check if user exists
check_user_exists() {
    local username="$1"
    psql -h "$PG_HOST" -p "$PG_PORT" -U "$PG_USER" -d postgres -tAc "SELECT 1 FROM pg_roles WHERE rolname='$username'" | grep -q 1
}

# Function to execute SQL commands
execute_sql() {
    local sql="$1"
    local description="$2"
    local database="${3:-postgres}"

    print_info "Executing: $description"
    if PGPASSWORD="$PG_PASSWORD" psql -h "$PG_HOST" -p "$PG_PORT" -U "$PG_USER" -d "$database" -c "$sql"; then
        print_success "$description - completed"
    else
        print_error "$description - failed"
        exit 1
    fi
}

# Function to test database connectivity
test_connectivity() {
    local host="$1"
    local port="$2"
    local username="$3"
    local password="$4"
    local user_type="$5"

    print_info "Testing $user_type connectivity via ${host}:${port}..."

    # Test basic connection
    if PGPASSWORD="$password" psql -h "$host" -p "$port" -U "$username" -d "$DBNAME" -c "SELECT 1 as connection_test;" > /dev/null 2>&1; then
        print_success "$user_type connection successful"
        return 0
    else
        print_error "$user_type connection failed"
        return 1
    fi
}

# Function to run all connectivity tests
run_connectivity_tests() {
    if [[ "$ENABLE_LB_TEST" != "true" ]]; then
        print_info "Load balancer testing is disabled. Skipping connectivity tests."
        return 0
    fi

    print_info "Starting connectivity tests via load balancer..."

    local test_failed=0

    # Test owner user connection
    if ! test_connectivity "$LB_HOST" "$LB_PORT" "$USER_OWNER" "$USER_OWNER_PASSWORD" "OWNER"; then
        test_failed=1
    fi

    # Test app user connection
    if ! test_connectivity "$LB_HOST" "$LB_PORT" "$USER_APP" "$USER_APP_PASSWORD" "APP"; then
        test_failed=1
    fi

    if [[ $test_failed -eq 0 ]]; then
        print_success "All connectivity tests passed via load balancer!"
        print_info "Database is accessible via ${LB_HOST}:${LB_PORT}"
    else
        print_error "Some connectivity tests failed. Please check your load balancer configuration."
        return 1
    fi

    return 0
}

# Main execution function
main() {
    print_info "Starting PostgreSQL database creation process..."

    # Check if PostgreSQL is running
    check_postgres

    # Load and validate configuration
    load_config

    # Check if database already exists
    if check_database_exists; then
        print_error "Database '$DBNAME' already exists"
        exit 1
    fi

    # Check if users already exist
    if check_user_exists "$USER_APP"; then
        print_error "User '$USER_APP' already exists"
        exit 1
    fi

    if check_user_exists "$USER_OWNER"; then
        print_error "User '$USER_OWNER' already exists"
        exit 1
    fi

    # Generate passwords if not provided
    if [[ -z "$USER_APP_PASSWORD" ]]; then
        USER_APP_PASSWORD=$(generate_password)
        print_info "Generated password for $USER_APP: $USER_APP_PASSWORD"
    fi

    if [[ -z "$USER_OWNER_PASSWORD" ]]; then
        USER_OWNER_PASSWORD=$(generate_password)
        print_info "Generated password for $USER_OWNER: $USER_OWNER_PASSWORD"
    fi

    print_info "Creating database: $DBNAME"

    # Execute SQL commands
    execute_sql "CREATE DATABASE $DBNAME;" "Create database $DBNAME"

    execute_sql "ALTER SCHEMA public RENAME TO $USER_OWNER;" "Connect to database $DBNAME and rename schema to $USER_OWNER" "$DBNAME"

    execute_sql "ALTER DATABASE $DBNAME SET search_path TO $USER_OWNER, public;" "Set search path" "$DBNAME"

    execute_sql "CREATE USER $USER_APP WITH PASSWORD '$USER_APP_PASSWORD';" "Create application user $USER_APP" "postgres"

    execute_sql "CREATE USER $USER_OWNER WITH PASSWORD '$USER_OWNER_PASSWORD';" "Create owner user $USER_OWNER" "postgres"

    execute_sql "GRANT CONNECT ON DATABASE $DBNAME TO $USER_OWNER;" "Grant connect to owner user" "postgres"

    execute_sql "REVOKE ALL ON DATABASE $DBNAME FROM PUBLIC;" "Revoke public database privileges" "postgres"

    execute_sql "REVOKE CREATE ON SCHEMA $USER_OWNER FROM PUBLIC;" "Revoke public schema create privileges" "$DBNAME"

    execute_sql "CREATE ROLE $ROLE_RW;" "Create read-write role $ROLE_RW" "postgres"

    execute_sql "GRANT CONNECT ON DATABASE $DBNAME TO $ROLE_RW;" "Grant connect to read-write role" "postgres"

    execute_sql "GRANT USAGE ON SCHEMA $USER_OWNER TO $ROLE_RW;" "Grant schema usage to read-write role" "$DBNAME"

    execute_sql "GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA $USER_OWNER TO $ROLE_RW;" "Grant table permissions to read-write role" "$DBNAME"

    execute_sql "ALTER DEFAULT PRIVILEGES FOR ROLE $USER_OWNER GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO $ROLE_RW;" "Set default table privileges for read-write role" "$DBNAME"

    execute_sql "GRANT USAGE ON ALL SEQUENCES IN SCHEMA $USER_OWNER TO $ROLE_RW;" "Grant sequence usage to read-write role" "$DBNAME"

    execute_sql "ALTER DEFAULT PRIVILEGES FOR ROLE $USER_OWNER GRANT USAGE, SELECT ON SEQUENCES TO $ROLE_RW;" "Set default sequence privileges for read-write role" "$DBNAME"

    execute_sql "ALTER DEFAULT PRIVILEGES FOR ROLE $USER_OWNER GRANT EXECUTE ON FUNCTIONS TO $ROLE_RW;" "Set default function privileges for read-write role" "$DBNAME"

    execute_sql "CREATE ROLE $ROLE_RC;" "Create creator role $ROLE_RC" "postgres"

    execute_sql "GRANT CONNECT ON DATABASE $DBNAME TO $ROLE_RC;" "Grant connect to creator role" "postgres"

    execute_sql "GRANT USAGE, CREATE ON SCHEMA $USER_OWNER TO $ROLE_RC;" "Grant schema usage and create to creator role" "$DBNAME"

    execute_sql "GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA $USER_OWNER TO $ROLE_RC;" "Grant table permissions to creator role" "$DBNAME"

    execute_sql "GRANT USAGE ON ALL SEQUENCES IN SCHEMA $USER_OWNER TO $ROLE_RC;" "Grant sequence usage to creator role" "$DBNAME"

    execute_sql "GRANT TEMPORARY ON DATABASE $DBNAME TO $ROLE_RC;" "Grant temporary database access to creator role" "postgres"

    execute_sql "GRANT CREATE ON DATABASE $DBNAME TO $ROLE_RC;" "Grant database create to creator role" "postgres"

    execute_sql "GRANT $ROLE_RW TO $USER_APP;" "Grant read-write role to application user" "postgres"

    execute_sql "GRANT $ROLE_RC TO $USER_OWNER;" "Grant creator role to owner user" "postgres"

    print_success "Database '$DBNAME' created successfully!"
    print_info "Database connection details:"
    print_info "  Host: $PG_HOST"
    print_info "  Port: $PG_PORT"
    print_info "  Database: $DBNAME"
    print_info "  Application User: $USER_APP"
    print_info "  Owner User: $USER_OWNER"

    if [[ -n "$SAVE_CREDENTIALS_FILE" ]]; then
        cat > "$SAVE_CREDENTIALS_FILE" << EOF
# Database Credentials - $(date)
Database: $DBNAME
Host: $PG_HOST
Port: $PG_PORT

Application User: $USER_APP
Application Password: $USER_APP_PASSWORD

Owner User: $USER_OWNER
Owner Password: $USER_OWNER_PASSWORD
EOF
        print_success "Credentials saved to: $SAVE_CREDENTIALS_FILE"
    fi

    # Run connectivity tests via load balancer if enabled
    if ! run_connectivity_tests; then
        print_error "Connectivity tests failed. Database was created but load balancer access is not working."
        exit 1
    fi
}

# Help function
show_help() {
    cat << EOF
PostgreSQL Database Creation Script

Usage: $0 [config_file]

Arguments:
    config_file    Path to configuration file (default: db_config.conf)

Options:
    -h, --help     Show this help message

Description:
    This script creates a PostgreSQL database with proper security configuration
    including users, roles, and permissions based on the provided configuration file.

Examples:
    $0                          # Use default config file (db_config.conf)
    $0 my_db.conf               # Use custom config file
    $0 --help                   # Show help message
EOF
}

# Parse command line arguments
case "${1:-}" in
    -h|--help)
        show_help
        exit 0
        ;;
    *)
        main
        ;;
esac