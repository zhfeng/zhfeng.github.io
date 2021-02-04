# Comparison with Camel Quarkus and Camel Spring Boot GraalVM Native
Today we use two ways to generate the native execution of a camel
application and compare their performance. The sample application uses
the camel-openapi component and Camel REST DSL to illustrate a simple
REST services. The
[camel-quarkus-openapi-example](https://github.com/zhfeng/camel-quarkus-openapi-example)
uses the [Camel Quarkus](https://camel.apache.org/camel-quarkus/latest/)
framework. And
[camel-example-spring-boot-rest-openapi](https://github.com/zhfeng/camel-spring-boot-examples/tree/camel-spring-boot-examples-3.7.0-graalvm/camel-example-spring-boot-rest-openapi)
uses [Spring Boot](https://projects.spring.io/spring-boot/) with
[Camel](http://camel.apache.org/) and
[Spring Native for GraalVM](https://github.com/spring-projects-experimental/spring-native).

## Prerequisites
- Maven 3.6.2+
- JDK 11
- GraalVM 20.3.0

## Dependencies
- Quarkus 1.11.0.Final
- Camel 3.7.0
- Spring Boot 2.4.0
- Spring Native 0.8.3

## Build naive image
If you have not installed GraalVM 20.3.0, please download from [GraalVM
Releases](https://github.com/graalvm/graalvm-ce-builds/releases) at
first and get ***native_image*** by using
```
gu install native-image
```
Also, refer to
[GraalVM native-image manual](https://www.graalvm.org/reference-manual/native-image/#install-native-image)
if you get problems.

Then we can build camel-quarkus-openapi-example and it is very
simple to follow the steps.

```
git clone https://github.com/zhfeng/camel-quarkus-openapi-example
cd camel-quarkus-openapi-example
export GRAALVM_HOME /path/to/graalvm-ce-java11-20.3.0
./mvw package -Pnative 
```

To build the camel-example-spring-boot-rest-openapi, I have made some
changes to run with spring native library. So the following steps

```
git clone https://github.com/zhfeng/camel-spring-boot-examples
cd camel-spring-boot-examples
git checkout camel-spring-boot-examples-3.7.0-graalvm
cd camel-example-spring-boot-rest-openapi
export GRAALVM_HOME /path/to/graalvm-ce-java11-20.3.0
./compile.sh
```
### NOTE
I use the
[native-image-agent](https://www.graalvm.org/reference-manual/native-image/BuildConfiguration/)
to get the graalvm configuration files during building the
camel-spring-boot-examples with spring native library. So all of them
have been in the repo now.If you want to see how they are
generated, you could use the following steps to start the application.

```
export LD_LIBRARY_PATH=$GRAALVM_HOME/lib
java -agentlib:native-image-agent=config-out-dir=src/main/resources/META-INF/native-image -jar target/camel-example-spring-boot-rest-openapi-3.7.0.jar
```
and run curl to get results.

```
curl http://localhost:8080/api/api-docs
curl http://localhost:8080/api/users
```

Now we get the successful builds and have two native executions
(camel-quarkus-openapi-example-1.0.0-SNAPSHOT-runner and
camel-example-spring-boot-rest-openapi).

## Performance comparison
You can use the [compare.sh](../../../assets/files/compare.sh) to get
the applications running and find a report such as

| Runtime        | Startup    | Boot + First Response Delay | Disk Size | Resident Set Size |
| -------------  | ---------- | ----------------------------|-----------|-------------------|
| Spring Native  |     0.174s |                       196ms |       98M |           152204K |
| Quarkus Native |     0.022s |                        82ms |       97M |            61784K |

Then we can see that camel quarkus native is about 8x faster than spring native one to startup.
Also it has the less RSS memory. The camel quarkus have more optimizations to get initializing
at the build time. That's the reason for faster startup time and low memory footprint.