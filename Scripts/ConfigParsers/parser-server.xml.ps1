﻿# Author: Scott Sutherland, NetSPI (@_nullbind / nullbind)

function Parse-UserPasswordFromXML {
    param (
        [string]$filePath
    )

    # Load the XML file
    [xml]$xmlContent = Get-Content -Path $filePath

    # Define an array to store the user credentials
    $credentials = @()

    # Parse basicRegistry user credentials
    $xmlContent.server.basicRegistry.user | ForEach-Object {
        $credentials += [pscustomobject]@{
            User     = $_.name
            Password = $_.password
            Source   = 'basicRegistry'
        }
    }

    # Parse variable-based credentials (DB_USER and DB_PASS)
    $dbUser = $xmlContent.server.variable | Where-Object { $_.name -eq "DB_USER" }
    $dbPass = $xmlContent.server.variable | Where-Object { $_.name -eq "DB_PASS" }

    if ($dbUser -and $dbPass) {
        $credentials += [pscustomobject]@{
            User     = $dbUser.value
            Password = $dbPass.value
            Source   = 'variable'
        }
    }

    # Parse containerAuthData credentials
    $xmlContent.server.dataSource.containerAuthData | ForEach-Object {
        $credentials += [pscustomobject]@{
            User     = $_.user
            Password = $_.password
            Source   = 'containerAuthData'
        }
    }

    # Parse authData credentials
    $xmlContent.server.authData | ForEach-Object {
        $credentials += [pscustomobject]@{
            User     = $_.user
            Password = $_.password
            Source   = 'authData'
        }
    }

    # Return the collected credentials as an array of objects
    return $credentials
}

# Example usage:
$parsedCredentials = Parse-UserPasswordFromXML -filePath "c:\temp\configs\server.xml"

# Display the results
$parsedCredentials | Format-Table -AutoSize


<# server.xml 

<!--
    Copyright (c) 2017,2023 IBM Corporation and others.
    All rights reserved. This program and the accompanying materials
    are made available under the terms of the Eclipse Public License 2.0
    which accompanies this distribution, and is available at
    http://www.eclipse.org/legal/epl-2.0/
    
    SPDX-License-Identifier: EPL-2.0
   
    Contributors:
        IBM Corporation - initial API and implementation
 -->
<server>
  <include location="../fatTestPorts.xml" />

  <featureManager>
    <feature>componenttest-1.0</feature>
    <feature>restConnector-2.0</feature>
    <feature>jdbc-4.2</feature>
    <feature>mpOpenApi-1.0</feature>
  </featureManager>

  <variable name="onError" value="FAIL"/>

  <keyStore id="defaultKeyStore" password="Liberty"/>
  
  <basicRegistry>
    <user name="adminuser" password="adminpwd" />
    <user name="reader" password="readerpwd" />
    <user name="user" password="userpwd" />
  </basicRegistry>
  <administrator-role>
    <user>adminuser</user>
  </administrator-role>
  <reader-role>
    <user>reader</user>
  </reader-role>
  
  <library id="Derby">
    <file name="${shared.resource.dir}/derby/derby.jar"/>
  </library>
  
  <variable name="DB_USER" value="dbuser"/>
  <variable name="DB_PASS" value="dbpass"/>

  <dataSource id="DataSourceWithoutJDBCDriver" jndiName="jdbc/withoutJDBCDriver" connectionSharing="MatchCurrentState" transactional="false">
    <containerAuthData id="dbuser-auth" user="dbuser" password="{xor}Oz0vPiws"/>
   	<properties.derby.embedded databaseName="memory:withoutJDBCDriver"/>
  </dataSource>

  <dataSource id="DefaultDataSource" isolationLevel="TRANSACTION_READ_COMMITTED">
    <jdbcDriver libraryRef="Derby"/>
    <!-- user/password settings defined in bootstrap.properties -->
   	<properties.derby.embedded databaseName="memory:defaultdb" createDatabase="create" 
   	                           user="${DB_USER}" password="${DB_PASS}"/>
  </dataSource>

  <dataSource id="jdbc/nonexistentdb" jndiName="${id}">
    <connectionManager id="NestedConPool" agedTimeout="1h2m3s" connectionTimeout="0s" maxIdleTime="40m" reapTime="2m30s"/>
    <jdbcDriver libraryRef="Derby"/>
   	<properties.derby.embedded databaseName="memory:doesNotExist"/>
  </dataSource>

  <transaction enableHADBPeerLocking="false">
    <dataSource transactional="false" containerAuthDataRef="auth1">
      <connectionManager maxPoolSize="5" connectionTimeout="0s"/>
      <jdbcDriver libraryRef="Derby"/>
   	  <properties.derby.embedded databaseName="memory:recoverydb" createDatabase="create"/>
    </dataSource>
  </transaction>

  <!-- ejbLite and batch features are intentionally disabled -->
  <databaseStore id="unavailableDBStore">
    <dataSource id="unavailableDS">
      <jdbcDriver libraryRef="Derby"/>
      <properties.derby.embedded databaseName="memory:unavailabledb"/>
    </dataSource>
  </databaseStore>

  <!-- mongo feature intentionally disabled, so it doesn't matter that we are using an incorrect library -->
  <mongo id="mongo" libraryRef="DerbyLib"/>
  <mongoDB id="MongoDBNotEnabled" jndiName="mongo/db" mongoRef="mongo" databaseName="db-test" />
  
  <authData id="auth1" user="dbuser" password="dbpass"/>
  
  <authData id="auth2" user="dbuser" password="wrong_password"/>
  
  <dataSource jndiName="jdbc/defaultauth" containerAuthDataRef="auth1"> <!-- id omitted for testing -->
    <connectionManager enableSharingForDirectLookups="false"/>  
    <jdbcDriver id="NestedDerbyDriver" libraryRef="Derby"
     javax.sql.DataSource="org.apache.derby.jdbc.EmbeddedDataSource"
     javax.sql.ConnectionPoolDataSource="org.apache.derby.jdbc.EmbeddedConnectionPoolDataSource"
     javax.sql.XADataSource="org.apache.derby.jdbc.EmbeddedXADataSource"/>
    <onConnect>SET CURRENT SCHEMA = APP</onConnect>
    <onConnect>SET CURRENT SQLID = APP</onConnect>
    <properties.derby.embedded databaseName="memory:defaultdb" createDatabase="create"/>
  </dataSource>

  <dataSource id="WrongDefaultAuth" jndiName="jdbc/wrongdefaultauth"
    connectionManagerRef="pool1" containerAuthDataRef="auth2" commitOrRollbackOnCleanup="rollback"
    invalidProperty="The property's value." jdbcDriverRef="DerbyDriver" queryTimeout="2m10s"
    recoveryAuthDataRef="auth2" statementCacheSize="15" validationTimeout="20s">
    <properties databaseName="memory:defaultdb" createDatabase="create"/>
  </dataSource>

  <connectionManager id="pool1" maxPoolSize="10" purgePolicy="ValidateAllConnections"/>

  <jdbcDriver id="DerbyDriver" libraryRef="Derby"/>
  
  <javaPermission codebase="${shared.resource.dir}/derby/derby.jar" className="java.security.AllPermission"/>
</server>


#>