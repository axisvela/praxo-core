(import '[com.axisvela.praxo.agent Agent AgentOptions Session]
        '[com.axisvela.praxo.model Message Model Request Response])

(def model
  (reify Model
    (generate [_ request]
      (Response/of (Message/of "assistant" "hello from Clojure")))))

(def result (.run (Agent. (AgentOptions. model)) (Session. "demo") "hello"))

(when-not (= "hello from Clojure" (.output result))
  (throw (ex-info "unexpected output" {:output (.output result)})))

(println "Clojure sample passed:" (.output result))
