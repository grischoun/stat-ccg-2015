(ns custom-incanter
  (:require
   [incanter.charts :as ic]
   [incanter.core :as i]))

(defn hist
  [values title]
  {:pre [(sequential? values)]}
  (let [freq (frequencies values)
        f #(freq % 0)
        ks (keys freq)
        a (apply min ks)
        b (apply max ks)
        x-values (range a (inc b))
        x-labels (map str x-values)
        y-values (map f x-values)]
    (ic/bar-chart x-labels y-values :title title)))
