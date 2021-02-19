# Comparison with Camel Quarkus and Camel Spring Boot GraalVM Native
Today, we show two ways to compile a Camel
application to native image and compare their performance: 
[Camel Quarkus](https://camel.apache.org/camel-quarkus/latest/) 
and [Camel](http://camel.apache.org/)+[Spring Boot](https://projects.spring.io/spring-boot/)+[Spring Native for GraalVM](https://github.com/spring-projects-experimental/spring-native).

In both cases, the sample application uses
the camel-openapi component and Camel REST DSL to illustrate a simple
REST services. Here is the source code:

* [camel-quarkus-openapi-example](https://github.com/zhfeng/camel-quarkus-openapi-example)
* [camel-example-spring-boot-rest-openapi](https://github.com/zhfeng/camel-spring-boot-examples/tree/camel-spring-boot-examples-3.7.0-graalvm/camel-example-spring-boot-rest-openapi).

## Prerequisites
- Maven 3.6.2+
- JDK 11
- GraalVM 20.3.0

If you have not installed GraalVM 20.3.0, please download from [GraalVM
Releases](https://github.com/graalvm/graalvm-ce-builds/releases) at
first and get ***native_image*** by using
```
gu install native-image
```
Also, refer to
[GraalVM native-image manual](https://www.graalvm.org/reference-manual/native-image/#install-native-image)
if you get problems.

## Dependencies
- Quarkus 1.11.0.Final
- Camel 3.7.0
- Spring Boot 2.4.0
- Spring Native 0.8.3

## Build the native images

### Quarkus
Building a native image on Quarkus is as easy as issuing `./mvnw package -Pnative`:

```
git clone https://github.com/zhfeng/camel-quarkus-openapi-example
cd camel-quarkus-openapi-example
export GRAALVM_HOME /path/to/graalvm-ce-java11-20.3.0
./mvnw package -Pnative 
```

Note that you do not need to care for configuring GraalVM `native-image` tool at all. 
Quarkus does it all for you under the hood.

### SpringBoot native
To build the Camel SpringBoot application, I had to make some
changes to run with spring native library. The steps are as follows:

```
git clone https://github.com/zhfeng/camel-spring-boot-examples
cd camel-spring-boot-examples
git checkout camel-spring-boot-examples-3.7.0-graalvm
cd camel-example-spring-boot-rest-openapi
export GRAALVM_HOME /path/to/graalvm-ce-java11-20.3.0
./compile.sh
```

I used the
[native-image-agent](https://www.graalvm.org/reference-manual/native-image/BuildConfiguration/)
to get the graalvm configuration files. 
I had to run the application with the agent attached and send some requests so that the agent can record which classes need to get registered for reflection, etc.


Here is what I did:
```
$GRAALVM_HOME/bin/java -agentlib:native-image-agent=config-out-dir=src/main/resources/META-INF/native-image -jar target/camel-example-spring-boot-rest-openapi-3.7.0.jar
```
and run curl to send some requests.

```
curl http://localhost:8080/api/api-docs
curl http://localhost:8080/api/users
```

`native-image-agent` outputs the configuration when the test application terminates. 
I have checked in the configuration to git so that you do not need to perform those steps yourselves.

You can also check *compile.sh* to find the `native-image` command to
compile the SpringBoot app.

## Performance comparison

As a result of the the previous steps, we got two native executables
(`camel-quarkus-openapi-example-1.0.0-SNAPSHOT-runner` and
`camel-example-spring-boot-rest-openapi`).

Now we can use the [compare.sh](../../../assets/files/compare.sh) script to collect some numbers.

Here are the results on my Lenovo P50 laptop

| Runtime        | Time to first response | Disk Size | Resident Set Size |
|----------------|------------------------|-----------|-------------------|
| Spring Native  |                  196ms |       98M |           152204K |
| Quarkus Native |                   82ms |       97M |            61784K |

We can see that Camel Quarkus native is about 2x faster than SpringBoot native to startup.
The Quarkus application also occupies less RSS memory. Camel Quarkus moves more initialization tasks from runtime to
the build time. That's the reason for faster startup time and lower memory footprint.

## Acknowledgement

I'd like to thank [Peter Palaga](https://github.com/ppalaga) for his
reviewing and the outstanding suggestions.
