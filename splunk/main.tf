terraform {
  required_providers {
    splunk = {
      source  = "splunk/splunk"
      version = "1.4.12"
    }
  }
  required_version = ">= 1.0"
}

provider "splunk" {
  url                  = "example.com:8089"
  username             = "user"
  password             = "pass"
  insecure_skip_verify = true
  // Or use environment variables:
  // SPLUNK_USERNAME
  // SPLUNK_PASSWORD
  // SPLUNK_URL
  // SPLUNK_INSECURE_SKIP_VERIFY (Defaults to true)
}

### Users
resource "splunk_authentication_users" "pliuta" {
  name              = "user2"
  email             = "e@ma.il"
  password          = "pass"
  force_change_pass = false
  roles             = ["admin", "sc_admin", "user"]
}

### Dashboards
resource "splunk_data_ui_views" "dashboard" {
  name     = "dashboard"
  eai_data = file("${path.module}/dashboards/dashboard.xml")
}

### Indexes
resource "splunk_indexes" "oracle_process_log" {
  name                   = "oracle_process_log"
  max_total_data_size_mb = 500
}

### Apps
resource "splunk_apps_local" "splunk_app_db_connect" {
  filename         = true
  name             = "/opt/splunk-db-connect_380.tgz" ### This is path on server, not local!
  explicit_appname = "splunk_app_db_connect"
}
resource "splunk_apps_local" "splunk-dbx-add-on-for-oracle-jdbc" {
  filename         = true
  name             = "/opt/splunk-dbx-add-on-for-oracle-jdbc_210.tgz"
  explicit_appname = "Splunk_JDBC_oracle"
}

### DB identity
# list of configs: /services/properties
resource "splunk_configs_conf" "db_identity" {
  # name = ${any of /services/properties}/{new configuration record}
  name = "identities/terraform-identity"
  acl {
    app = "splunk_app_db_connect"
    owner   = "nobody"
    sharing = "global"
  }
  variables = {
    username : "terr-user"
    password : "my-pass"
  }
  depends_on = [splunk_apps_local.splunk_app_db_connect]
}

### DB connection
resource "splunk_configs_conf" "db_connection" {
  name = "db_connections/terraform-connection"
  acl {
    app = "splunk_app_db_connect"
    owner   = "nobody"
    sharing = "global"
  }
  variables = {
    connection_type : "oracle"
    database : "my-db"
    host : "example.com"
    port : 1521
    identity : "terraform-identity" # TODO: read this from identity resource
    # jdbcUseSSL : false
    timezone : "Israel"
  }
  depends_on = [splunk_configs_conf.db_identity]
}
### DB Inputs
resource "splunk_configs_conf" "db_input"{
  name = "db_inputs/terraformInput"
  acl {
    app = "splunk_app_db_connect"
    owner   = "nobody"
    sharing = "global"
  }
  variables = {
    batch_upload_size : "1000"
    fetch_size : "300"
    max_rows : "0"
    max_single_checkpoint_file_size : "10485760"
    mode : "rising"
    query_timeout : "30"
    sourcetype : "myoracle_sourcetype"
    tail_rising_column_init_ckpt_value : "{\"value\":\"1\",\"columnType\":2}"
    tail_rising_column_name : "START_TIME"
    tail_rising_column_number : "3"
    disabled : "0"

    connection : "terraform-connection" # TODO: read this from connection resource 
    index : "oracle_process_log" # TODO: read this from index resource
    index_time_mode : "dbColumn"
    input_timestamp_column_number : "3"
    input_type : "event"
    interval : "*/10 * * * *"
    mode : "rising"
    query : "SELECT t.*, end_time-start_time as duration\nFROM \"LOG\" t\nWHERE START_TIME > ?\nORDER BY START_TIME DESC;"
  }
  depends_on = [ 
    splunk_configs_conf.db_connection,
    splunk_indexes.oracle_process_log
  ]
}
