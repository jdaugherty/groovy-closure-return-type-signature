# A statically compiled closure's return type signature depends on what else is compiled

With static compilation, the `doCall` method of a closure is declared with the closure's inferred return type. When
that type is a parameterized type whose class is compiled in the same compilation unit, Groovy drops its type
arguments. When the class is already compiled, Groovy keeps them. So the same source compiles to a closure class with
a different signature depending on what else is compiled, which incremental builds and build caches see as a change.

Reproduced with Groovy 4.0.33, 5.1.3 and `master`.

## The difference

Four files in `lib/src/main/groovy/example`:

```groovy
interface Up {}

class Res<T> {
    List<T> items = []
}

class Util {
    static String label() { 'loading' }
}

@CompileStatic
class Svc {
    static <V> V timeIt(String label, Closure<V> body) { println label; body.call() }

    def <U extends Up> Res<U> read(Class<U> type) { new Res<U>() }

    Res<Up> load(Class<Up> type) {
        timeIt(Util.label()) { -> read(type) }
    }
}
```

The closure in `load` returns `Res<Up>`. Compile `Svc` together with `Res`, and again against the compiled `Res`.
`javap` on the closure class `Svc$_load_closure1` shows:

```
public example.Res doCall();           Svc compiled together with Res
public example.Res<example.Up> doCall(); Svc compiled against the compiled Res
```

`groovyc-repro.sh` does this with `groovyc` alone, no build tool involved.

## In an incremental build

`demo.sh` runs the same thing through Gradle 9.8.0 with incremental Groovy compilation and the
`GROOVY_COMPILATION_AVOIDANCE` feature preview:

1. a full build of `:app`, where `lib` compiles `Res` and `Svc` together;
2. a change to a method body in `Util`, which `Svc` uses only inside a method body;
3. an incremental build, where `lib` recompiles `Util` and `Svc` against the compiled `Res`.

With Groovy 5.1.3:

```
> Task :lib:compileGroovy
Incremental compilation of 3 classes completed in 0.762 secs.
Task ':app:compileGroovy' is not up-to-date because:
  Input property 'classpath' file .../lib/build/libs/lib.jar has changed.
None of the classes needs to be compiled!

== 4. doCall of Svc$_load_closure1, full build then incremental build:
  public example.Res doCall();
   ---
  public example.Res<example.Up> doCall();
```

`Svc.groovy` did not change, but the binary API of its closure class did, so the downstream project's compile task
runs again. The closure class is only referenced from `Svc`, so nothing downstream needs recompiling here, but the jar
of `lib` differs from a full build, and so does everything keyed on it, such as build cache entries.

The pattern occurs in Grails applications: `@Transactional` and similar transformations move a method body into a new
method without the original method's type parameters, so a closure there that returned `Res<U>` returns a concrete
`Res<Up>`.

## Cause

`ClosureWriter.createClosureClass` normalises the inferred return type with:

```java
else if (returnType.isPrimaryClassNode()) returnType = returnType.getPlainNodeReference();
```

`isPrimaryClassNode()` is true for the class node of a class in the compilation unit and for every reference to it,
including a parameterized one such as `Res<Up>`, and `getPlainNodeReference()` drops the type arguments. A reference
to a class read from bytecode is not primary, so it keeps them.

## Fix

Only the class node itself, which carries the declared type parameters rather than type arguments, should be replaced
by its plain reference. A parameterized reference then goes through the same check for unresolved generics as any
other type, and both builds produce `Res<Up> doCall()`, the signature a closure already gets for a parameterized
library type such as `List<String>`.

The fix, with a test that compiles both ways and compares the signatures, is on these branches of
[jdaugherty/groovy](https://github.com/jdaugherty/groovy):

- [`closure-return-type-signature`](https://github.com/jdaugherty/groovy/tree/closure-return-type-signature), based on `master`;
- [`closure-return-type-signature-5_1_X`](https://github.com/jdaugherty/groovy/tree/closure-return-type-signature-5_1_X), based on `GROOVY_5_1_X`.

## Running it

```
./groovyc-repro.sh    # groovyc alone; needs groovyc on the PATH, or GROOVYC set to a groovyc command
./demo.sh             # Gradle: full build, body change, incremental build, doCall before and after
```

Both scripts leave the sources as they found them. The Groovy version is set in `gradle.properties`. To try the fix,
publish a Groovy branch to the local Maven repository and pass its version:

```
# in a clone of jdaugherty/groovy, branch closure-return-type-signature-5_1_X, with JDK 17 or later
./gradlew publishToMavenLocal -x :groovy-binary:publishToMavenLocal -x javadoc -x groovydoc

# here
./demo.sh -PgroovyVersion=5.1.4-SNAPSHOT
```

With the fix, both builds show `public example.Res<example.Up> doCall();` and `:app:compileGroovy` stays up to date.
