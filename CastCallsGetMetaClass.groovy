import org.codehaus.groovy.runtime.InvokerHelper

// A Groovy class whose getMetaClass() has a side effect, as a Spring class-based proxy (CGLIB) of a Groovy
// class does: the proxy forwards getMetaClass() to its target, so for a step- or request-scoped bean it needs
// the scope to be active.
class Watched {
    static int metaClassCalls = 0
    static boolean failMetaClass = false

    @Override
    MetaClass getMetaClass() {
        metaClassCalls++
        if (failMetaClass) {
            throw new IllegalStateException('getMetaClass() called: the target behind this proxy is not available')
        }
        InvokerHelper.getMetaClass(Watched)
    }
}

String mode = "indy=${System.getProperty('groovy.target.indy', 'true (default)')}"
Object value = new Watched()

// 1. A cast of a value that already has the target type counts getMetaClass() calls.
Watched.metaClassCalls = 0
Watched typed = value
println "${mode}: getMetaClass() calls made by `Watched typed = value`: ${Watched.metaClassCalls}"

// 2. The same cast of another instance, when getMetaClass() cannot be answered.
Object other = new Watched()
Watched.failMetaClass = true
try {
    Watched typedOther = other
    println "${mode}: cast with a failing getMetaClass(): OK"
}
catch (IllegalStateException e) {
    println "${mode}: cast with a failing getMetaClass(): ${e.message}"
}
