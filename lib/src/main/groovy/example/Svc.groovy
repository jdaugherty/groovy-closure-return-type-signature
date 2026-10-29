package example

import groovy.transform.CompileStatic

@CompileStatic
class Svc {
    static <V> V timeIt(String label, Closure<V> body) {
        println label
        body.call()
    }

    def <U extends Up> Res<U> read(Class<U> type) {
        new Res<U>()
    }

    Res<Up> load(Class<Up> type) {
        timeIt(Util.label()) { -> read(type) }
    }
}
