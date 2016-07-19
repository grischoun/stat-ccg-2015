(defproject stat-ccg-2015 "0.1.0-SNAPSHOT"
  :description "Statisctics for the CCG season 2015-16"
  :dependencies [[org.clojure/clojure "1.8.0"]
                 [yesql "0.5.3"]
                 [org.postgresql/postgresql "9.4-1201-jdbc41"]
                 [incanter "1.5.4"]
                 ]
  :main ^:skip-aot gorilla-test.core
  :target-path "target/%s"
  :plugins [[lein-gorilla "0.3.6"]
            [cider/cider-nrepl "0.13.0-snapshot"]]
  :profiles {:uberjar {:aot :all}})
