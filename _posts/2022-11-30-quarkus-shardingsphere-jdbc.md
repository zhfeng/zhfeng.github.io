# Integrate with Apache ShardingSphere JDBC and Quarkus
## Introduction
[Apache ShardingSphere](https://shardingsphere.apache.org) is a great flexible ecosystem to transform any database into a distributed database system, and enhance it with sharding, elastic scaling, encryption features and more. [Quarkus](https://quarkus.io) is a Kubernetes Native Java stack tailored for OpenJDK HotSpot and GraalVM, crafted from the best of breed Java libraries and standards. It is a great framework to build microservices and serverless applications. In this article, I will show you how to integrate with Apache ShardingSphere JDBC and Quarkus.

## Prerequisites
* JDK 11+
* Maven 3.8.4
* Create a new project with Quarkus
```shell
mvn io.quarkus:quarkus-maven-plugin:create \
    -DprojectGroupId=org.apache.shardingsphere.example \
    -DprojectArtifactId=shardingsphere-quarkus-example \
    -DclassName="org.apache.shardingsphere.example.ShardingSphereQuarkusExample" \
    -Dpath="/hello" \
    -Dextensions="resteasy-jsonb, hibernate-orm, jdbc-h2, shardingsphere-jdbc"
```
---
**NOTE:**  
Currently Quarkus haven't upgraded REST Assured and thus Groovy because of https://issues.apache.org/jira/browse/GROOVY-10307. So we have to set `io.rest-assured:rest-assured` version with **5.2.0** in the pom.xml explicitly because `shardingsphere-jdbc` is using Groovy 4.x
---

## Build and Running
Now you need to `cd shardingsphere-quarkus-example` and run `mvn clean install`. If you meet an issue such like
```
Caused by: groovy.lang.MissingMethodException: No signature of method: io.restassured.internal.http.HTTPBuilder.parseResponse() is applicable for argument types:
```
and please make sure to set `io.rest-assured:rest-assured` version with **5.2.0**

### Datasources configuration
We can add two `H2` datasources `ds_0` and `ds_1` in `application.properties` for testing
```properties
quarkus.datasource.ds_0.db-kind=h2
quarkus.datasource.ds_0.username=sa
quarkus.datasource.ds_0.jdbc.url=jdbc:h2:mem:ds_0

quarkus.datasource.ds_1.db-kind=h2
quarkus.datasource.ds_1.username=sa
quarkus.datasource.ds_1.jdbc.url=jdbc:h2:mem:ds_1
```

Also, we can add a `shardingsphere` datasource
```properties
quarkus.datasource.db-kind=shardingsphere
quarkus.datasource.jdbc.url=jdbc:shardingsphere:classpath:config.yaml`
```

Please refer to [Quarkus Datasource](https://cn.quarkus.io/guides/datasource) and [ShardingSphere JDBC Driver](https://shardingsphere.apache.org/document/current/en/user-manual/shardingsphere-jdbc/yaml-config/jdbc_driver/) for more details.

### ShardingSphere configuration
Then we will create `config.yaml` for ShardingSphere configuration. Let's have a simple rule for sharding database `ds_0` and `ds_1` by using `user_id`. 
```yaml
databaseName: sharding_db

dataSources:
  ds_0:
    dataSourceClassName: io.quarkiverse.shardingsphere.jdbc.QuarkusDataSource
    dsName: ds_0
  ds_1:
    dataSourceClassName: io.quarkiverse.shardingsphere.jdbc.QuarkusDataSource
    dsName: ds_1

rules:
  - !SHARDING
    tables:
      t_user:
        actualDataNodes: ds_${0..1}.t_user
        keyGenerateStrategy:
          column: user_id
          keyGeneratorName: snowflake
          
    defaultDatabaseStrategy:
      standard:
        shardingColumn: user_id
        shardingAlgorithmName: database-inline

    defaultTableStrategy:
      none:

    shardingAlgorithms:
      database-inline:
        type: INLINE
        props:
          algorithm-expression: ds_${user_id % 2}

    keyGenerators:
      snowflake:
        type: SNOWFLAKE
```

Refer to [ShardingSphere Document](https://shardingsphere.apache.org/document/current/en/user-manual/shardingsphere-jdbc/yaml-config/rules) for more details of Sharding rules.

### User model
We are using `quarkus-hibernate-orm` to access the databases and define a `User` Entity.

```java
import javax.persistence.Entity;
import javax.persistence.Id;
import javax.persistence.Table;

@Entity
@Table(name = "t_user")
public class User {
    @Id
    private int user_id;
    private String name;

    public int getUser_id() {
        return user_id;
    }

    public void setUser_id(int user_id) {
        this.user_id = user_id;
    }
    
    public String getName() {
        return name;
    }
    
    public void setName(String name) {
        this.name = name;
    }
}
```

Refer to [Quarkus Hibernate ORM](https://cn.quarkus.io/guides/hibernate-orm) for more details.

### Create REST services
Open `ShardingSphereQuarkusExample.java` and add the following codes:

```java
@Path("/users")
public class ShardingSphereQuarkusExample {
    @Inject
    EntityManager entityManager;

    @GET
    @Produces(MediaType.APPLICATION_JSON)
    public List<User> getAllUsers() {
        return entityManager.createQuery("SELECT a FROM User a", User.class).getResultList();
    }

    @POST
    @Consumes(MediaType.APPLICATION_JSON)
    @Transactional
    public void addUser(User user) {
        entityManager.persist(user);
    }

    @Path("/{ds}")
    @GET
    @Produces(MediaType.TEXT_PLAIN)
    public Integer countUsers(@PathParam("ds") String ds) throws Exception {
        DataSource dataSource = Arc.container().instance(DataSource.class, NamedLiteral.of(ds)).get();

        try (Connection connection = dataSource.getConnection();
             Statement statement = connection.createStatement()) {
            ResultSet resultSet = statement.executeQuery("SELECT COUNT(*) FROM t_user");
            resultSet.next();
            return resultSet.getInt(1);
        }
    }
}
```

---
**NOTE:**
When inserting a user into the database, shardingsphere routes it to the different database according to the sharding rules. Also, it controls the transaction by itself, so we need to disable the transaction support in the agroal. Also, shardingsphere can support multi types of backend databases, so we have to set `quarkus.hibernate-orm.dialect` explicitly to `io.quarkus.hibernate.orm.runtime.dialect.QuarkusH2Dialect` for H2 database. 
```properties
quarkus.datasource.ds_0.jdbc.transactions=DISABLED
quarkus.datasource.ds_1.jdbc.transactions=DISABLED

quarkus.hibernate-orm.dialect=io.quarkus.hibernate.orm.runtime.dialect.QuarkusH2Dialect
```
---

* GET `/users` will return all users in the database
* POST `/users` will insert a user into the database
* GET `/users/{ds}` will return the count of users in the database `{ds}`

## Testing
Now we have all the codes ready, let's run the tests.
### Start an application
```shell
./mvnw clean package
java -jar target/quarkus-app/quarkus-run.jar
```

### Add users
```shell
curl -X POST -H "Content-Type: application/json" -d '{"user_id":1,"name":"User1"}' http://localhost:8080/users
curl -X POST -H "Content-Type: application/json" -d '{"user_id":2,"name":"User2"}' http://localhost:8080/users
```

### Check users in the database
```shell
curl http://localhost:8080/users
```
you can get
```
[{"name":"User2","user_id":2},{"name":"User1","user_id":1}]
```
then check the count of users in the database `ds_0` and `ds_1`
```shell
curl http://localhost:8080/users/ds_0
curl http://localhost:8080/users/ds_1
```
both of the results are `1`

## Conclusion
In this article, we are using `quarkus-shardingsphere-jdbc` to build a simple application with ShardingSphere. We can see that it is very easy to use ShardingSphere with Quarkus. Currently, it only supports JVM mode, and we are working on the native support. This is a big challenge for us since the shardingsphere default rule language is based on `groovy` which is not fully supported in native mode with Quarkus.

The whole demo project is available at [Github](https://github.com/zhfeng/shardingsphere-quarkus-example). Feel free to try it out and give us feedback.