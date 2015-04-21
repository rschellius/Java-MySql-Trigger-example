/**
 * 
 */
package nl.avans.ivp4;

import java.sql.Connection;
import java.sql.DriverManager;
import java.sql.PreparedStatement;
import java.sql.ResultSet;
import java.sql.SQLException;
import java.sql.Statement;
import java.util.Date;

/**
 * Example program to show how MySQL triggers are handled in a Java program.
 * 
 * @author Robin Schellius
 *
 */
public class MySqlExample {

	private Connection connect = null;
	private Statement statement = null;
	private PreparedStatement preparedStatement = null;
	private ResultSet resultSet = null;
	private String query = "";
	
	// Connectionstring to the database
	private final static String dbConnection = "jdbc:mysql://localhost/hh-trigger-voorbeeld?user=hartigehap&password=wachtwoord";

	/**
	 * Demo of the several possibilities of querying the database.
	 * 
	 * @throws Exception
	 */
	public void useDataBase() {
		
		try {
			// This will load the MySQL driver; each different DB provider has its own driver
			Class.forName("com.mysql.jdbc.Driver");
			System.out.println("Successfully found the database driver");
		} catch (Exception ex) {
			System.out.println("Exception: " + ex.getMessage());
		}
			
		try {
			// Setup the connection with the DB
			connect = DriverManager.getConnection(dbConnection);
			System.out.println("Successfully connected to the database");
			// Statements allows to issue SQL queries to the database
			statement = connect.createStatement();
		} catch (Exception ex) {
			System.out.println("Exception: " + ex.getMessage());
		}
		System.out.println();
			
		try {
			// Issue a select statement to the database.
			// Resultset gets the result of the SQL query
			query = "SELECT * FROM `bestelling`";
			System.out.println(query);
			resultSet = statement.executeQuery(query);
			writeResultSet(resultSet);
			// writeMetaData(resultSet);
		} catch (Exception ex) {
			System.out.println("Exception: " + ex.getMessage());
		}
		System.out.println();

		try {
			// Add a bestelling on a table that already has an bestelling open.
			// Should not be possible, so throw an exception

			// PreparedStatements can use variables and are more efficient
			// query = "insert into bestelling values (default, ?, ?, ?, ? , ?, ?)";
			query = "INSERT INTO `bestelling` (`TafelNummer`) VALUES (?)";
			preparedStatement = connect.prepareStatement(query);
			preparedStatement.setInt(1, 1);
			System.out.println(preparedStatement);
			preparedStatement.executeUpdate();
		} catch (Exception ex) {
			System.out.println("Exception: " + ex.getMessage());
		}
		System.out.println();
			
		try {
			// Add a new Bestelling for table 5.
			// Should be successful, since no bestelling is open on table 5.
			query = "INSERT INTO `bestelling` (`TafelNummer`) VALUES (?)";
			preparedStatement = connect.prepareStatement(query);
			preparedStatement.setInt(1, 5);
			System.out.println(preparedStatement);
			preparedStatement.executeUpdate();
		} catch (Exception ex) {
			System.out.println("Exception: " + ex.getMessage());
		}
		System.out.println();

		try {
			// Show the contents of the bestelling table
			query = "SELECT * FROM `bestelling`";
			preparedStatement = connect.prepareStatement(query);
			System.out.println(query);
			resultSet = preparedStatement.executeQuery();
			writeResultSet(resultSet);
		} catch (Exception ex) {
			System.out.println("Exception: " + ex.getMessage());
		}
		System.out.println();

		try {
			// Try to add a new bestelling that does NOT have status = OPEN
			// Should throw an exception, since .
			query = "INSERT INTO `bestelling` (`TafelNummer`, `Status`) VALUES (?, ?)";
			preparedStatement = connect.prepareStatement(query);
			preparedStatement.setInt(1, 3);
			preparedStatement.setString(2, "GEANNULEERD");
			System.out.println(preparedStatement);
			preparedStatement.executeUpdate();
		} catch (Exception ex) {
			System.out.println("Exception: " + ex.getMessage());
		}
		System.out.println();
				
		try {
			// Update the status of an existing bestelregel
			// Should succeed: OPEN > GEREED is allowed.
			query = "UPDATE `bestelregel` SET `Status` = ? WHERE `Barcode` = ?";
			preparedStatement = connect.prepareStatement(query);
			preparedStatement.setString(1, "GEREED");
			preparedStatement.setString(2, "10000002");
			System.out.println(preparedStatement);
			preparedStatement.executeUpdate();

			query = "SELECT * FROM `bestelregel`";
			preparedStatement = connect.prepareStatement(query);
			resultSet = preparedStatement.executeQuery();
			writeResultSet(resultSet);
		} catch (Exception ex) {
			System.out.println("Exception: " + ex.getMessage());
		}
		System.out.println();

		// Finally, close the connection to the database.
		close();
	}

	/**
	 * Example of how to print metadata from a resultset.
	 * Notice that we don't know the exact columnnames and amount of columns;
	 * this is extracted from the resultset.
	 * 
	 * @param resultSet
	 * @throws SQLException
	 */
	private void writeMetaData(ResultSet resultSet) throws SQLException {

		System.out.println("The columns in the table are: ");

		System.out.println("Table: " + resultSet.getMetaData().getTableName(1));
		for (int i = 1; i <= resultSet.getMetaData().getColumnCount(); i++) {
			System.out.println("Column " + i + " "
					+ resultSet.getMetaData().getColumnName(i));
		}
	}

	/**
	 * Write the contents of a resultset.
	 * Notice that we simply print all columns and values in the resultset.
	 * 
	 * @param resultSet
	 * @throws SQLException
	 */
	private void writeResultSet(ResultSet resultSet) throws SQLException {
		
		int columnCount = resultSet.getMetaData().getColumnCount();		
		System.out.println("\nTable: " + resultSet.getMetaData().getTableName(1));

		while (resultSet.next()) {

			for (int i = 1; i <= columnCount; i++) {
				System.out.print(resultSet.getMetaData().getColumnName(i) + ": " + resultSet.getString(i) + "\t");
			}
			System.out.println();
		}
	}

	/**
	 * You need to close the resultSet after its last use.
	 */
	private void close() {
		try {
			if (resultSet != null) {
				resultSet.close();
			}

			if (statement != null) {
				statement.close();
			}

			if (connect != null) {
				connect.close();
			}
		} catch (Exception e) {

		}
	}

	/**
	 * Exampe Main method to start the program.
	 * 
	 * @param args
	 */
	public static void main(String[] args) {
		
		MySqlExample dao = new MySqlExample();
		dao.useDataBase();
	}

}
