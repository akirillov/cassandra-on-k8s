package com.mesosphere;

import com.datastax.oss.driver.api.core.CqlSession;
import com.datastax.oss.driver.api.core.cql.ResultSet;
import com.datastax.oss.driver.api.core.cql.Row;
import com.datastax.oss.driver.api.core.cql.SimpleStatement;

import java.net.InetSocketAddress;

public class CassandraClient {
    public static void main(String... args){
        try (CqlSession session = CqlSession.builder()
                .addContactPoint(new InetSocketAddress("127.0.0.1", 9042))
                .withKeyspace("multidc")
                .withLocalDatacenter("DC1")

                .build()) {

            //TO DO: execute SimpleStatement that retrieves one user from the table
            //TO DO: print firstname and age of user
            ResultSet rs = session.execute(
                    SimpleStatement.builder("SELECT * FROM users WHERE lastname=?")
                            .addPositionalValue("test")
                            .build());

            Row row = rs.one();
            System.out.format("%s %d\n", row.getString("firstname"), row.getInt("age"));
        }
    }
}
