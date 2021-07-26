// https://docs.microsoft.com/en-us/dotnet/framework/data/adonet/sql/single-bulk-copy-operations
using System;
using System.IO;
using System.Data.SqlClient;
using System.Text;
using System.Data;
using System.Collections.Generic;
using Microsoft.Extensions.Configuration;



namespace sql
{
    class Program
    {
        static void Main(string[] args)
        {
            //// keyvault name
            string sqlServerDataSource = "";

            //// Client ID from the output of service pricipal creation output
            string userId = "";

            //// Tenant ID from the output of service pricipal creation output
            string userPassword = "";

            //// Password from the output of service pricipal creation output
            string dbName = "";

            Dictionary<string, string> listValues = new Dictionary<string, string>();
            Console.WriteLine($"reading variable from the file jsconfig1.json");
            listValues = GetParameters();
            foreach (KeyValuePair<string, string> kvp in listValues)
            {
                switch (kvp.Key)
                {
                    case "sqlServerDataSource":
                        sqlServerDataSource = kvp.Value;
                        Console.WriteLine($"sqlServerDataSource= \"{kvp.Value}\"");
                        break;
                    case "userId":
                        userId = kvp.Value;
                        Console.WriteLine($"userId= \"{kvp.Value}\"");
                        break;
                    case "userPassword":
                        userPassword = kvp.Value;
                        Console.WriteLine($"userPassword= \"{kvp.Value}\"");
                        break;
                    case "dbName":
                        dbName = kvp.Value;
                        Console.WriteLine($"dbName= \"{kvp.Value}\"");
                        break;
                    default:
                        Console.WriteLine("ERROR in reading .json file");
                        System.Environment.Exit(0);
                        break;
                }
            }

            try
            {
                SqlConnectionStringBuilder builder = new SqlConnectionStringBuilder();

                builder.DataSource = sqlServerDataSource;
                builder.UserID = userId;
                builder.Password = userPassword;
                builder.InitialCatalog = dbName;

                using (SqlConnection connection = new SqlConnection(builder.ConnectionString))
                {
                    Console.WriteLine("\nQuery data example:");
                    Console.WriteLine("=========================================\n");

                    connection.Open();

                    String sql = "SELECT name, collation_name FROM sys.databases";

                    using (SqlCommand command = new SqlCommand(sql, connection))
                    {
                        using (SqlDataReader reader = command.ExecuteReader())
                        {
                            while (reader.Read())
                            {
                                Console.WriteLine("{0} {1}", reader.GetString(0), reader.GetString(1));
                            }
                        }
                    }
                }
            }
            catch (SqlException e)
            {
                Console.WriteLine(e.ToString());
            }
            Console.WriteLine("\nDone. Press enter.");
            Console.ReadLine();

            try
            {
                SqlConnectionStringBuilder builder = new SqlConnectionStringBuilder();
                builder.DataSource = sqlServerDataSource;
                builder.UserID = userId;
                builder.Password = userPassword;
                builder.InitialCatalog = dbName;

                // Create the connection.
                using (SqlConnection connection = new SqlConnection(builder.ConnectionString))
                {
                    Console.WriteLine("\nCreate tables:");
                    Console.WriteLine("=========================================\n");

                    connection.Open();
                    string query = "";
                    SqlCommand cmd;

                    query = sql_CreateTables();
                    cmd = new SqlCommand(query, connection);
                    cmd.ExecuteNonQuery();
                    Console.WriteLine("table {0} created successfully", query);

                    query = sql_Inserts();
                    cmd = new SqlCommand(query, connection);
                    cmd.ExecuteNonQuery();
                    Console.WriteLine("table {0} created successfully", query);

                    query = sql_AddColum();
                    cmd = new SqlCommand(query, connection);
                    cmd.ExecuteNonQuery();
                    Console.WriteLine("add column to the table: {0}", query);

                    // change column Stock nvarchar(50) to Stock int.
                    query = @"ALTER TABLE Products
                              ALTER COLUMN Stock int;";
                    cmd = new SqlCommand(query, connection);
                    cmd.ExecuteNonQuery();
                    Console.WriteLine("change the type of Stock column: {0}", query);


                    // change column Stock nvarchar(50) to Stock int.
                    query = @"ALTER TABLE Products
                              DROP COLUMN Stock;";
                    cmd = new SqlCommand(query, connection);
                    cmd.ExecuteNonQuery();
                    Console.WriteLine("delete the Stock column: {0}", query);

                    query = sql_CreateTableCustomers();
                    cmd = new SqlCommand(query, connection);
                    cmd.ExecuteNonQuery();
                    Console.WriteLine("add table: {0}", query);
                }

            }
            catch (SqlException e)
            {
                Console.WriteLine("Error: {0}", e.ToString());
            }
        }
        static string sql_CreateTables()
        {
            return @"
            DROP TABLE IF EXISTS dbo.Employee;
            DROP TABLE IF EXISTS dbo.Department; 
            DROP TABLE IF EXISTS dbo.Products; 

            CREATE TABLE dbo.Department
            (
               DepartmentCode  nchar(4)          not null    PRIMARY KEY,
               DepartmentName  nvarchar(128)     not null
            );

            CREATE TABLE dbo.Employee
            (
               EmployeeGuid    uniqueIdentifier  not null  default NewId()    PRIMARY KEY,
               EmployeeName    nvarchar(128)     not null,
               EmployeeLevel   int               not null,
               Subcompany      nvarchar(255)     not null,
               DepartmentCode  nchar(4)              null
            );
            CREATE TABLE dbo.Products
            (
                ID int IDENTITY(1,1) NOT NULL,
                Name nvarchar(50) NULL,
                Price nvarchar(50) NULL,
                Date datetime NULL,
                CONSTRAINT pk_id PRIMARY KEY (ID)
             );
            ";
        }

        static string sql_Inserts()
        {
            return @"
        -- The company has these departments.
        INSERT INTO Department (DepartmentCode, DepartmentName)
        VALUES
            ('acct', 'Accounting'),
            ('hres', 'Human Resources'),
            ('eng',  'Engineering'),
            ('legl', 'Legal');

        -- The company has these employees, each in one department.
        INSERT INTO Employee (EmployeeName, EmployeeLevel, Subcompany, DepartmentCode)
        VALUES
            ('Frank'   , 50, 'contos1','acct'),
            ('Rob'     , 50, 'contos1','hres'),
            ('Carol'   , 20, 'contos1','acct'),
            ('Deborah' , 20, 'contos1','legl'),
            ('Rachel'  , 30, 'contos1', null),
            ('Eva'     , 30, 'contos1', 'eng'),
            ('Mike'    , 40,  'contos1','eng'),
            ('Robert'  , 40, 'contos1','acct'),
            ('Jack'    , 60, 'contos1','acct'),
            ('Jason'   , 40, 'contos1','eng');

        INSERT INTO Products ( Name, Price, Date)
        VALUES
            ('SpikeSpan', '$9.50', 10-12-2020),
            ('Dash','$8.50', 14-03-2020),
            ('Prosciutto', '$5.50', 17-07-2020),
            ('Lamb leg' ,'$13.50', 21-06-2020);
            ";
        }

        static string sql_AddColum()
        {
            return @"
                  ALTER TABLE Products
                  ADD Stock nvarchar(50);
            ";
        }
        static string sql_CreateTableCustomers()
        {
            return @"
                  CREATE TABLE dbo.Customers
                  (
                  CustomerID int IDENTITY(1,1) NOT NULL,
                  CustomerName nvarchar(50) NULL,
                  ContactName nvarchar(100) NULL,
                  Address nvarchar(100) NULL,
                  City 	 nvarchar(30) NULL,
                  PostalCode nvarchar(20) NULL,
                  Country nvarchar(20) NULL
                  )
            ";
        }

        // read the file "jsconfig1.json" and load the key, value pairs in the dictionary
        private static Dictionary<string, string> GetParameters()
        {
            var builder = new ConfigurationBuilder()
                .SetBasePath(Directory.GetCurrentDirectory())
                .AddJsonFile("json1.json", optional: true, reloadOnChange: true);
            var val1 = builder.Build().GetSection("sqlServerDataSource").Value;
            var val2 = builder.Build().GetSection("userId").Value;
            var val3 = builder.Build().GetSection("userPassword").Value;
            var val4 = builder.Build().GetSection("dbName").Value;
            Dictionary<string, string> listValues = new Dictionary<string, string>();
            listValues.Add("sqlServerDataSource", val1);
            listValues.Add("userId", val2);
            listValues.Add("userPassword", val3);
            listValues.Add("dbName", val4);
            return listValues;
        }
        static public void InsertRows(SqlConnection connection)
        {
            SqlParameter parameter;

            using (var command = new SqlCommand())
            {
                command.Connection = connection;
                command.CommandType = CommandType.Text;
                command.CommandText = @"  
INSERT INTO SalesLT.Product  
		(Name,  
		ProductNumber,  
		StandardCost,  
		ListPrice,  
		SellStartDate  
		)  
	OUTPUT  
		INSERTED.ProductID  
	VALUES  
		(@Name,  
		@ProductNumber,  
		@StandardCost,  
		@ListPrice,  
		CURRENT_TIMESTAMP  
		); ";

                parameter = new SqlParameter("@Name", SqlDbType.NVarChar, 50);
                parameter.Value = "SQL Server Express 2014";
                command.Parameters.Add(parameter);

                parameter = new SqlParameter("@ProductNumber", SqlDbType.NVarChar, 25);
                parameter.Value = "SQLEXPRESS2014";
                command.Parameters.Add(parameter);

                parameter = new SqlParameter("@StandardCost", SqlDbType.Int);
                parameter.Value = 11;
                command.Parameters.Add(parameter);

                parameter = new SqlParameter("@ListPrice", SqlDbType.Int);
                parameter.Value = 12;
                command.Parameters.Add(parameter);

                int productId = (int)command.ExecuteScalar();
                Console.WriteLine("The generated ProductID = {0}.", productId);
            }
        }
    }
}

