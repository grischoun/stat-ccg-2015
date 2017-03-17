# stat-ccg-2015

;; HOW-TO
;; ------
;; -- in shell:
;; lein gorilla
;;
;; -- db side
;; !!! Need to create the VIEWS manually until we migrate to postgres 9.3 where materialized views are availble. I.e. needs to go into DataGrip and execute all the SQLs in stat.sql.
;;
;; -- in emacs:
;; cider-connect <port returned by lein gorilla>
;; eval (C-c C-k) db-spec.clj first
;; eval (C-c C-k) stat.clj
;;
;; -- in gorilla repl (i.e in the browser)
;;
;; * start the browser with the link returned on the command line by lein gorilla
;; * to load an existing worksheet in the online viewer: ctrl-g ctrl-l
;;
;; (ns stat
;;   (:require [gorilla-plot.core :as plot]))
;; (plot/bar-chart categories values)
;;
;; -- online viewer
;;http://viewer.gorilla-repl.org/view.html?source=github&user=grischoun&repo=stat-ccg-2015&path=stat-ccg-html.clj
;;
;; to reload a worksheet in the online viewer: ctrl-g ctrl-l
;;
