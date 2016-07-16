;; HOW-TO
;; ------
;; -- in shell:
;; lein gorilla
;;
;; -- in emacs:
;; cider-connect <port returned by lein gorilla>
;; eval (C-c C-k) db-spec.clj first
;; eval (C-c C-k) stat.clj
;;
;; -- in gorilla repl
;; (ns stat
;;   (:require [gorilla-plot.core :as plot]))
;; (plot/bar-chart categories values)
;;
;; -- online viewer
;;http://viewer.gorilla-repl.org/view.html?source=github&user=grischoun&repo=stat-ccg-2014&path=ws/main.clj
;;
;; to reload a worksheet in the online viewer: ctrl-g ctrl-l
;;
;; -- db side
;; !!! Need to create the VIEWS manually until we migrate to postgres 9.3 where materialized views are availble. I.e. needs to go into DataGrip and execute all the SQLs in stat.sql.
;;


(ns stat
  (:require [yesql.core :refer [defqueries]])
  (:require [db-spec :refer [db-spec]])
  (:require [gorilla-plot.core :as plot])
  (:require [gorilla-repl.html :as html])
  (:require [gorilla-repl.table :as table])
  )


(defqueries "stat.sql" {:connection db-spec})

;; (ends-played-distribution db-spec)

(defn row
  [row_name rows]
  "Retrieves the values labeled 'row_name' in 'rows'"
  (vec (map #(row_name %) rows))
  )

(defn first_21
  [row_name rows]
  "Retrieves the first 21 values labeled 'row_name' in 'rows'"
  (take 21 (row row_name rows))
  )

(defn last_21
  [row_name rows]
  "Retrieves the last 21 values labeled 'row_name' from 'rows'"
  (drop 21 (row row_name rows))
  )


(def ends-played (ends-played-distribution))

(def ends-played-nb (row :ends_count ends-played))
(def ends-count  (row :count ends-played))


(def end-score-dist (row :score (end-score-distribution)))


(def played-ends-count (ends-count-per-team ))
(def matches-count (matches-count-per-team ))
(def ends-won (ends-won-per-match ))
(def ends-received (ends-received-per-match ))
(def points-avg (points-per-match ))
(def points-received (points-received-per-match ))

(defn format-dec
  [f]
  (format "%.3f" f))

;; the table that summerizes the data
(def table (map (fn [x]
                  [(:equipes x)
                   (:wins x)
                   (:tied x)
                   (:lost x)
                   (format-dec (:ends_won_per_match x))
                   (format-dec (:ends_received_per_match x))
                   (format-dec (:points_per_match x))
                   (format-dec (:points_received_per_match x))
                   ])
                (stat-per-team )))


;; stone color wins per sheet
(def stone-color-res (stone-color-per-sheet))
(defn sheet-res
  "Returns the rows for sheet x"
  [x]
  (filter #(= (:rink %) x) stone-color-res))
(defn x-axis-for
  "Returns the string to show on the x axis"
  [res]
  (map (fn [x] (str "Piste " (:rink x) ": " (:winner_color x))) res))
(defn y-axis-for
  "Returns the string to show on the y axis"
  [res]
  (map (fn [x] (:count x)) res))
;; (def sheet-a (sheet-res "A"))
(defn plot-sheet
  "Plot the bar-chart"
  [x]
  (plot/bar-chart (x-axis-for (sheet-res x)) (y-axis-for (sheet-res x))))
;; (def plot-sheet-a (plot-sheet "A"))
;; (def sheet-a-x (x-axis-for sheet-a)) ;; x axis for sheet a
;; (def sheet-a-y (map (fn [x] (:count x)) sheet-a)) ;; y axis for sheet a


;; scores
;;

;; sum of team's and opponent's score
(defn total-score
  [league]
  (vec (map #(:total_score %) (cond
                                (= "ALL" league) (scores)
                                (= "A" league) (scores-league-x)))))

;; delta of team's and opponent's score
(defn delta-score
  [league]
  (vec (map #(:delta_score %) (cond
                                (= "ALL" league) (scores)
                                (= "A" league) (scores-league-x)))))
