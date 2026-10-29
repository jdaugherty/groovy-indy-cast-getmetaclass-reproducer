# invokedynamic casts call `getMetaClass()` on the value being cast

With invokedynamic (the default since Groovy 4), a cast of a `GroovyObject` that already has the target type, such as
`Widget widget = value`, calls `value.getMetaClass()`. With classic call sites the same cast calls nothing on the value.

That is observable whenever `getMetaClass()` is not a plain field read. A Spring class-based (CGLIB) proxy of a Groovy
class forwards every public method, `getMetaClass()` included, to its target. For a step-, job-, request- or
session-scoped bean the target exists only while the scope is active, so merely assigning the proxy to a typed variable
outside the scope fails:

```
org.springframework.beans.factory.support.ScopeNotActiveException: Error creating bean with name 'scopedTarget.widget':
    Scope 'step' is not active for the current thread
  at org.springframework.aop.target.SimpleBeanTargetSource.getTarget(SimpleBeanTargetSource.java:35)
  at org.springframework.aop.framework.CglibAopProxy$DynamicAdvisedInterceptor.intercept(CglibAopProxy.java:698)
  at Widget$$SpringCGLIB$$0.getMetaClass
  at org.codehaus.groovy.vmplugin.v8.Selector$MethodSelector.setGuards
  at org.codehaus.groovy.vmplugin.v8.Selector$CastSelector.castAndSetGuards
  at org.codehaus.groovy.vmplugin.v8.Selector$CastSelector.setCallSiteTarget
  at org.codehaus.groovy.vmplugin.v8.IndyInterface.fallback
  ...
  at WidgetSpec.casts the step-scoped proxy outside a step(WidgetSpec.groovy:12)   // Widget widget = context.getBean('widget', Widget)
```

A Grails application moving from `grails { indy = false }` to invokedynamic (the Grails 9 default) meets this in code that
handles scoped proxies dynamically.

## Reproducer

`CastCallsGetMetaClass.groovy` has no dependencies. `Watched` counts calls to `getMetaClass()`, and can throw from it
as an inactive scoped proxy does. `run.sh` runs it with `-Dgroovy.target.indy=true` and `false`:

```
$ ./run.sh 5.1.3 6.0.0 6.0.1-SNAPSHOT
== Groovy 5.1.3
   indy=true: getMetaClass() calls made by `Watched typed = value`: 2
   indy=true: cast with a failing getMetaClass(): getMetaClass() called: the target behind this proxy is not available
   indy=false: getMetaClass() calls made by `Watched typed = value`: 0
   indy=false: cast with a failing getMetaClass(): OK
== Groovy 6.0.0
   (same as 5.1.3)
== Groovy 6.0.1-SNAPSHOT
   (same as 5.1.3)
```

## Cause

`Selector.CastSelector.castAndSetGuards()` builds the cast handle and then reuses `MethodSelector.setGuards(args[0])`,
which, for a `GroovyObject` receiver, calls `receiver.getMetaClass()` to bind a `SAME_MC` metaclass-equality guard
(`Selector.java`, `setGuards(Object receiver)`, "special guards for receiver"). That guard is meant for method selection,
where the selected method depends on the receiver's metaclass. A cast's handle depends only on the value's class, which
the call site's `explicitCastArguments` / class checks already cover, so the metaclass read is unnecessary and is the
only reason the value is touched.

## Suggested fix

Guard a cast on the value's class rather than its metaclass, or skip the receiver metaclass guard in
`CastSelector.castAndSetGuards()`. Either keeps a cast free of calls into the value, as with classic call sites.

## Environment

JDK 25.0.4 (Liberica), macOS. Reproduced on Groovy 5.1.3, 6.0.0 and 6.0.1-SNAPSHOT (GROOVY_6_0_X at c9c1f8dfdf), all
with invokedynamic; none with classic call sites.
