-- name: count-all-matches
-- count all matches
select count(*) from matches;

-- name: count-matches
-- matches count
select count(*)
FROM competitions
JOIN tournaments ON competitions.id = tournaments.competition_id
JOIN rounds ON tournaments.id = rounds.tournament_id
  JOIN groups ON rounds.id = groups.round_id
  JOIN matches ON groups.id = matches.group_id
where competition_id = 22; -- Replace competition_id with the right year

-- drop view ENDS_PIERRES;

-- !!!! THIS DOES NOT CONSIDER/INCLUDE 'FORFEIT MATCHES' in the computation
CREATE OR REPLACE VIEW ENDS_PIERRES AS
            SELECT tournaments.id as tourn_id, matches.id as Match,
                   team_instances.id as team_instance_id,
                   team_instances.desc as equipes,
                   -- will be used for prioritizing a team in the ranking
                   MIN(groups.start_ranking_at) as start_ranking_at,
                   -- current team ends for current match
                   CASE WHEN COUNT(ends.id) IS NULL THEN 0
                        ELSE COUNT(ends.id)
                        END AS team_ends,
                   -- current team stones for current match
                   CASE WHEN SUM(ends.score) IS NULL THEN 0
                        ELSE SUM(ends.score)
                        END AS team_score,
                   -- current team ends for current match (excluding ends for extra ends)
                   (SELECT CASE WHEN COUNT(e2.id) IS NULL THEN 0
                           ELSE COUNT(e2.id)
                           END
                    FROM matches m2 inner join ends e2 ON e2.match_id = m2.id
                    WHERE e2.team_instance_id = team_instances.id AND m2.id = matches.id
                          -- exclude extra ends
                          AND e2.end_num <= number_of_ends
                    ) as team_ends_without_extra_ends,
                   -- current team stones for current match (excluding stones for extra ends)
                   (SELECT CASE WHEN SUM(e2.score) IS NULL THEN 0
                           ELSE SUM(e2.score)
                           END
                    FROM matches m2 inner join ends e2 ON e2.match_id = m2.id
                    WHERE e2.team_instance_id = team_instances.id AND m2.id = matches.id
                          -- exclude extra ends
                          AND e2.end_num <= number_of_ends
                    ) as team_score_without_extra_ends,
                   -- opponent team score for current match
                   (select CASE WHEN SUM(e2.score) IS NULL THEN 0
                           ELSE SUM(e2.score)
                           END
                    from matches m2 inner join ends e2 on e2.match_id = m2.id
                    where e2.team_instance_id <> team_instances.id and m2.id = matches.id) as opponent_score,
                    -- opponent team ends for current match
                    (select CASE WHEN count(e2.id) IS NULL THEN 0
                    ELSE count(e2.id)
                    END
                    from matches m2 inner join ends e2 on e2.match_id = m2.id
                    where e2.team_instance_id <> team_instances.id and m2.id = matches.id) as opponent_ends,
                   -- current team's lsd
                   CASE WHEN team_instances.id = matches.team_1_id THEN matches.lsd_1
                        WHEN team_instances.id = matches.team_2_id THEN matches.lsd_2
                        ELSE 0
                        END as lsd,
                   -- sets if match is (being) played or not
                   CASE WHEN (select COUNT(e2.id)
                              from matches m2
                              inner join ends e2 on e2.match_id = m2.id and
                                                    matches.id = m2.id) > 0 THEN 1
                        ELSE 0
                        END AS match_played,
                   -- number of ends played for current match
                   (select CASE WHEN COUNT(e2.id) IS NULL THEN 0
                           ELSE COUNT(e2.id)
                           END
                    from matches m2 inner join ends e2 on matches.id = m2.id AND e2.match_id = m2.id) as played_ends_count,
                   -- round num
                   round_num,
                   team_1_id,
                   team_2_id,
                   CASE WHEN matches.color_1 LIKE '%yellow%' THEN 'yellow'
                        WHEN lower(matches.color_1) LIKE '%#ffc900%' THEN 'yellow'
                        WHEN matches.color_1 LIKE '%#ffff00%' THEN 'yellow'
                        WHEN matches.color_1 LIKE '%red%' THEN 'red'
                        WHEN matches.color_1 LIKE '%#ff0000%' THEN 'red'
                        WHEN matches.color_1 LIKE '%#ff6000%' THEN 'red'
                        ELSE matches.color_1
                        END
                   as color1,
                   CASE WHEN matches.color_2 LIKE '%yellow%' THEN 'yellow'
                        WHEN lower(matches.color_2) LIKE '%#ffc900%' THEN 'yellow'
                        WHEN matches.color_2 LIKE '%#ffff00%' THEN 'yellow'
                        WHEN matches.color_2 LIKE '%red%' THEN 'red'
                        WHEN matches.color_2 LIKE '%#ff0000%' THEN 'red'
                        WHEN lower(matches.color_2) LIKE '%#ff6000%' THEN 'red'
                        ELSE matches.color_2
                        END
                   as color2,
                   rink
            FROM tournaments
                 INNER JOIN rounds ON rounds.tournament_id = tournaments.id
                 INNER JOIN groups ON groups.round_id = rounds.id
                 INNER JOIN matches ON matches.group_id = groups.id
                 INNER JOIN team_instances ON (matches.team_1_id = team_instances.id OR
                                               matches.team_2_id = team_instances.id)
                 INNER JOIN teams ON teams.id = team_instances.team_id
                 LEFT JOIN ends ON (ends.team_instance_id = team_instances.id AND matches.id = ends.match_id)
                 INNER JOIN match_configurations on matches.match_configuration_id = match_configurations.id
            -- !!! Don't add 'AND ends.score <> -1' below because that would exclude rows where the team_instance did not have any ends (i.e. where 'ends.score ISNULL')
            -- '.end_info_available = true' means that the match was not a forfeit
            WHERE tournaments.competition_id = 22 AND matches.end_info_available = true
            GROUP BY tournaments.id, matches.id, team_instances.id, number_of_ends, round_num;

-- drop view ENDS_PIERRES;

-- select team_ends, opponent_ends, played_ends_count, * from ENDS_PIERRES;

select  * from ENDS_PIERRES;



-- DROP VIEW MATCHES_V;

CREATE OR REPLACE VIEW MATCHES_V AS
  SELECT tournaments.id as tournament_id, c.id as competition_id, rounds.id as round_id, groups.id as group_id, matches.id as match_id
  FROM competitions c
    JOIN tournaments ON c.id = tournaments.competition_id
    JOIN rounds ON tournaments.id = rounds.tournament_id
    JOIN groups ON rounds.id = groups.round_id
    JOIN matches ON groups.id = matches.group_id
  WHERE competition_id = 22 AND matches.end_info_available = TRUE;

-- DROP VIEW ENDS_V;

CREATE OR REPLACE VIEW ENDS_V AS
  SELECT
    tournament_id,
    competition_id,
    round_id,
    group_id,
    m.match_id as match_id,
    id,
    end_num,
    team_instance_id,
    score,
    created_at,
    updated_at
  FROM MATCHES_V m
    JOIN ends ON m.match_id = ends.match_id
  WHERE competition_id = 22 AND ends.score <> -1 AND ends.end_num > 0;


-- DROP VIEW SCORES;

-- The difference between this and ENDS_PIERRES is that here we show only *one* entry/row per match
-- (whereas ENDS_PIERRES shows two entries/rows per match: one for team_1 and one for team_2
CREATE OR REPLACE VIEW SCORES AS
  SELECT tournaments.id as tourn_id, matches.id as Match,
                   team_instances.id as team_instance_id,
                   team_instances.desc as equipes,
                   -- current team stones for current match
                   CASE WHEN SUM(ends.score) IS NULL THEN 0
                        ELSE SUM(ends.score)
                        END AS team_score,
                   -- current team stones for current match (excluding stones for extra ends)
                   (SELECT CASE WHEN SUM(e2.score) IS NULL THEN 0
                           ELSE SUM(e2.score)
                           END
                    FROM matches m2 inner join ends e2 ON e2.match_id = m2.id
                    WHERE e2.team_instance_id = team_instances.id AND m2.id = matches.id
                          -- exclude extra ends
                          AND e2.end_num <= number_of_ends
                    ) as team_score_without_extra_ends,
                   -- opponent team score for current match
                   (select CASE WHEN SUM(e2.score) IS NULL THEN 0
                           ELSE SUM(e2.score)
                           END
                    from matches m2 inner join ends e2 on e2.match_id = m2.id
                    where e2.team_instance_id <> team_instances.id and m2.id = matches.id) as opponent_score,
                   -- sets if match is (being) played or not
                   CASE WHEN (select COUNT(e2.id)
                              from matches m2
                              inner join ends e2 on e2.match_id = m2.id and
                                                    matches.id = m2.id) > 0 THEN 1
                        ELSE 0
                        END AS match_played,
                   -- number of ends played for current match
                   (select CASE WHEN COUNT(e2.id) IS NULL THEN 0
                           ELSE COUNT(e2.id)
                           END
                    from matches m2 inner join ends e2 on matches.id = m2.id AND e2.match_id = m2.id) as played_ends_count,
                   -- round num
                   round_num,
                   team_1_id,
                   team_2_id,
                   CASE WHEN matches.color_1 LIKE '%yellow%' THEN 'yellow'
                        WHEN lower(matches.color_1) LIKE '%#ffc900%' THEN 'yellow'
                        WHEN matches.color_1 LIKE '%#ffff00%' THEN 'yellow'
                        WHEN matches.color_1 LIKE '%red%' THEN 'red'
                        WHEN matches.color_1 LIKE '%#ff0000%' THEN 'red'
                        WHEN matches.color_1 LIKE '%#ff6000%' THEN 'red'
                        ELSE matches.color_1
                        END
                   as color1,
                   CASE WHEN matches.color_2 LIKE '%yellow%' THEN 'yellow'
                        WHEN lower(matches.color_2) LIKE '%#ffc900%' THEN 'yellow'
                        WHEN matches.color_2 LIKE '%#ffff00%' THEN 'yellow'
                        WHEN matches.color_2 LIKE '%red%' THEN 'red'
                        WHEN matches.color_2 LIKE '%#ff0000%' THEN 'red'
                        WHEN lower(matches.color_2) LIKE '%#ff6000%' THEN 'red'
                        ELSE matches.color_2
                        END
                   as color2,
                   rink
            FROM tournaments
                 INNER JOIN rounds ON rounds.tournament_id = tournaments.id
                 INNER JOIN groups ON groups.round_id = rounds.id
                 INNER JOIN matches ON matches.group_id = groups.id
                 INNER JOIN team_instances ON matches.team_1_id = team_instances.id
                 INNER JOIN teams ON teams.id = team_instances.team_id
                 LEFT JOIN ends ON (ends.team_instance_id = team_instances.id AND matches.id = ends.match_id)
                 INNER JOIN match_configurations on matches.match_configuration_id = match_configurations.id
-- TODO: Do we also have to remove the ends.score and ends.end_num constraints below as we did for view ENDS_PIERRES?
            WHERE tournaments.competition_id = 22 AND matches.end_info_available = true
                  AND ends.score <> -1 -- NOTICE: will exclude rows where 'ends.score ISNULL'
                  AND ends.end_num > 0
            GROUP BY tournaments.id, matches.id, team_instances.id, number_of_ends, round_num;




-- DROP VIEW END_COUNT;

CREATE OR REPLACE VIEW END_COUNT AS
  SELECT matches.id as match_id, team_1_id, team_2_id, count(ends.id) AS ends_count
  FROM competitions
    JOIN tournaments ON competitions.id = tournaments.competition_id
    JOIN rounds ON tournaments.id = rounds.tournament_id
    JOIN groups ON rounds.id = groups.round_id
    JOIN matches ON groups.id = matches.group_id
    JOIN ends ON matches.id = ends.match_id
    -- end_num > 0 removes the handicap end
  WHERE competition_id = 22 AND ends.score <> -1 AND ends.end_num > 0 AND matches.end_info_available = TRUE
  GROUP BY matches.id;


-- name: ends-played-distribution
-- end count for each match
select ends_count, count(*)
FROM END_COUNT
GROUP BY ends_count
ORDER BY ends_count;

-- name: ends-played-distribution-with-teams
-- Shows the teams involved in a game that lasted X ends.
select ends_count, match_id, ti1."desc" as t1_desc, ti2."desc" as t2_desc
from end_count
  JOIN team_instances ti1 on ti1.id = END_COUNT.team_1_id
  JOIN team_instances ti2 on ti2.id = END_COUNT.team_2_id
  where ends_count = 4 OR ends_count = 5
ORDER BY ends_count
;

-- name: end-score-distribution
select score --, count(score)
from ENDS_V
--GROUP BY score
--ORDER BY score
;

-- select * from ENDS_PIERRES;

-- name: ends-count-per-team
select equipes,
  sum(played_ends_count) as ends_count
from ENDS_PIERRES
GROUP BY equipes
ORDER BY ends_count desc;

-- name: matches-count-per-team
select equipes,
  count(match) as matches_count
from ENDS_PIERRES
GROUP BY equipes
ORDER BY matches_count desc;

-- name: ends-won-per-match
select equipes,
  sum(team_ends) / count(match) as ends_won_per_match
from ENDS_PIERRES
GROUP BY equipes
ORDER BY ends_won_per_match desc;

-- name: ends-received-per-match
select equipes,
  sum(opponent_ends) / count(match) as ends_received_per_match
from ENDS_PIERRES
GROUP BY equipes
ORDER BY ends_received_per_match asc;

-- name: points-per-match
-- Points should be renamed stones here
select equipes,
  count(match),
  sum(team_score) / count(match) as points_per_match
from ENDS_PIERRES
GROUP BY equipes
ORDER BY points_per_match desc;

-- name: points-received-per-match
-- Points should be renamed stones here
select equipes,
  count(match),
  sum(opponent_score) / count(match) as points_per_match
from ENDS_PIERRES
GROUP BY equipes
ORDER BY points_per_match asc;


-- name: stat-per-team
-- Different stats for each team
select equipes,
  sum(case when team_score > opponent_score then 1 else 0 end) as wins,
  sum(case when team_score = opponent_score then 1 else 0 end) as tied,
  sum(case when team_score < opponent_score then 1 else 0 end) as lost,
  sum(played_ends_count) as ends_count,
  sum(team_ends) as ends_won,
  sum(team_ends) / count(match) as ends_won_per_match,
  sum(opponent_ends) / count(match) as ends_received_per_match,
  sum(team_score) as points_scored,
  sum(team_score) / count(match) as points_per_match,
  sum(opponent_score) / count(match) as points_received_per_match,
  count(match) as matches_count,
  sum(played_ends_count) / count(match) as ends_per_match
from ENDS_PIERRES
GROUP BY equipes
ORDER BY equipes ASC;

-- name: stone-color-per-sheet
-- # of wins per color on each sheet
select rink,
  case WHEN winner_color = 'red' then 'rouge'
    when winner_color = 'yellow' then 'jaune'
      else NULL
        END as winner_color
  , count(winner_color)
FROM (SELECT *, CASE WHEN team_score > opponent_score THEN color1
                when team_score < opponent_score THEN color2
                else NULL
                END as winner_color
      FROM (
             SELECT
               matches.id                                                     AS Match,
               -- current team stones for current match
               (SELECT CASE WHEN SUM(e2.score) IS NULL
                 THEN 0
                       ELSE SUM(e2.score)
                       END
                FROM matches m2 INNER JOIN ends e2 ON e2.match_id = m2.id
                WHERE e2.team_instance_id = team_1_id AND m2.id = matches.id) AS team_score,
               -- opponent team score for current match
               (SELECT CASE WHEN SUM(e2.score) IS NULL
                 THEN 0
                       ELSE SUM(e2.score)
                       END
                FROM matches m2 INNER JOIN ends e2 ON e2.match_id = m2.id
                WHERE e2.team_instance_id = team_2_id AND m2.id = matches.id) AS opponent_score,
               team_1_id,
               team_2_id,
               CASE WHEN matches.color_1 LIKE '%yellow%'
                 THEN 'yellow'
               WHEN lower(matches.color_1) LIKE '%#ffc900%'
                 THEN 'yellow'
               WHEN lower(matches.color_1) LIKE '%#ffff00%'
                 THEN 'yellow'
               WHEN matches.color_1 LIKE '%red%'
                 THEN 'red'
               WHEN lower(matches.color_1) LIKE '%#ff0000%'
                 THEN 'red'
               WHEN lower(matches.color_1) LIKE '%#ff6000%'
                 THEN 'red'
               ELSE matches.color_1
               END
                                                                              AS color1,
               CASE WHEN matches.color_2 LIKE '%yellow%'
                 THEN 'yellow'
               WHEN lower(matches.color_2) LIKE '%#ffc900%'
                 THEN 'yellow'
               WHEN lower(matches.color_2) LIKE '%#ffff00%'
                 THEN 'yellow'
               WHEN matches.color_2 LIKE '%red%'
                 THEN 'red'
               WHEN lower(matches.color_2) LIKE '%#ff0000%'
                 THEN 'red'
               WHEN lower(matches.color_2) LIKE '%#ff6000%'
                 THEN 'red'
               ELSE matches.color_2
               END
                                                                              AS color2,
               rink
             FROM tournaments
               INNER JOIN rounds ON rounds.tournament_id = tournaments.id
               INNER JOIN groups ON groups.round_id = rounds.id
               INNER JOIN matches ON matches.group_id = groups.id
               INNER JOIN team_instances ON (matches.team_1_id = team_instances.id OR
                                             matches.team_2_id = team_instances.id)
               INNER JOIN teams ON teams.id = team_instances.team_id
               LEFT JOIN ends ON (ends.team_instance_id = team_instances.id AND matches.id = ends.match_id)
               INNER JOIN match_configurations ON matches.match_configuration_id = match_configurations.id
             WHERE tournaments.competition_id = 22 AND ends.score <> -1 AND ends.end_num > 0 AND matches.end_info_available = TRUE
             GROUP BY matches.id
           ) AS main) as second
WHERE winner_color  NOTNULL
GROUP BY rink, winner_color
order by rink asc, winner_color


-- name: scores
-- # a summary on which to base all the statistics around scores
select team_score, opponent_score, (team_score + opponent_score) AS total_score, abs(team_score - opponent_score) as delta_score
FROM SCORES;


-- name: scores-league-x
select team_score, opponent_score, (team_score + opponent_score) AS total_score, abs(team_score - opponent_score) as delta_score
FROM SCORES
WHERE tourn_id = 199;


-- select * from ENDS_PIERRES where tourn_id = 199;
