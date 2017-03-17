-- DROP FUNCTION public.total_score(m_id integer, end_id integer, team_id INTEGER) CASCADE ;

CREATE OR REPLACE FUNCTION total_score(m_id INTEGER, team_id INTEGER)
  RETURNS BIGINT AS
$$
SELECT CASE WHEN SUM(score) IS NULL
  THEN 0
       ELSE SUM(score)
       END
FROM matches
  INNER JOIN ends ON matches.id = ends.match_id
WHERE ends.team_instance_id = team_id AND matches.id = m_id;
--where ends.team_instance_id = 4995 and matches.id = 14510;
$$ LANGUAGE SQL;


DROP VIEW MATCH_ENDS CASCADE;


SELECT end_num
FROM ends
WHERE ends.match_id = 1;

--
CREATE OR REPLACE VIEW MATCH_ENDS AS
  WITH scores AS (SELECT
                    CASE WHEN SUM(score) IS NULL
                      THEN 0
                    ELSE SUM(score)
                    END                AS team_score,
                    m.id               AS m_id,
                    e.team_instance_id AS team_id
                  FROM matches m
                    INNER JOIN ends e ON e.match_id = m.id
                  GROUP BY m.id, e.team_instance_id),
      score_deltas AS (SELECT
                         m.id          AS m_id,
                         ti.id         AS team_id,
                         e.end_num,
                         sum(e2.score) AS team_score
                       FROM matches m
                         INNER JOIN team_instances ti ON (m.team_1_id = ti.id OR m.team_2_id = ti.id)
                         LEFT JOIN ends e ON e.match_id = m.id
                         LEFT JOIN ends e2
                           ON e2.match_id = m.id AND e2.end_num <= e.end_num AND e2.team_instance_id = ti.id
                       -- where m.id = 1
                       GROUP BY m.id, ti.id, e.end_num
    )

  SELECT
    tournaments.id                                                                     AS tourn_id,
    matches.id                                                                         AS Match,
    team_instances.id                                                                  AS team_instance_id,
    team_instances.desc                                                                AS team_1_name,
    opponent_name,
    ends.end_num,
    ends.score                                                                         AS end_score,
    end_winner_id,
    -- team score for current match
    team_1_score,
    -- opponent team score for current match
    opponent_score,
    -- team 1 won or not
    CASE WHEN team_1_score > opponent_score
      THEN 1
    WHEN team_1_score < opponent_score
      THEN -1
    ELSE 0
    END                                                                                AS team_1_won,
    -- team_1 score - team_2 score at the current end.
    temp_team_1_score - temp_team_2_score                                              AS score_delta,
    -- team_1 total score at current end
    temp_team_1_score,
    -- team_2 total score at current end
    temp_team_2_score,
    -- current team ends for current match (excluding ends for extra ends)
    (SELECT CASE WHEN COUNT(e2.id) IS NULL
      THEN 0
            ELSE COUNT(e2.id)
            END
     FROM matches m2 INNER JOIN ends e2 ON e2.match_id = m2.id
     WHERE e2.team_instance_id = team_instances.id AND m2.id = matches.id
           -- exclude extra ends
           AND e2.end_num <= number_of_ends
    )                                                                                  AS team_ends_without_extra_ends,
    -- current team stones for current match (excluding stones for extra ends)
    (SELECT CASE WHEN SUM(e2.score) IS NULL
      THEN 0
            ELSE SUM(e2.score)
            END
     FROM matches m2 INNER JOIN ends e2 ON e2.match_id = m2.id
     WHERE e2.team_instance_id = team_instances.id AND m2.id = matches.id
           -- exclude extra ends
           AND e2.end_num <= number_of_ends
    )                                                                                  AS team_score_without_extra_ends,
    -- opponent team ends for current match
    (SELECT CASE WHEN count(e2.id) IS NULL
      THEN 0
            ELSE count(e2.id)
            END
     FROM matches m2 INNER JOIN ends e2 ON e2.match_id = m2.id
     WHERE e2.team_instance_id <> team_instances.id AND m2.id = matches.id)            AS opponent_ends,
    -- current team's lsd
    CASE WHEN team_instances.id = matches.team_1_id
      THEN matches.lsd_1
    WHEN team_instances.id = matches.team_2_id
      THEN matches.lsd_2
    ELSE 0
    END                                                                                AS lsd,
    -- sets if match is (being) played or not
    CASE WHEN (SELECT COUNT(e2.id)
               FROM matches m2
                 INNER JOIN ends e2 ON e2.match_id = m2.id AND
                                       matches.id = m2.id) > 0
      THEN 1
    ELSE 0
    END                                                                                AS match_played,
    -- number of ends played for current match
    (SELECT CASE WHEN COUNT(e2.id) IS NULL
      THEN 0
            ELSE COUNT(e2.id)
            END
     FROM matches m2 INNER JOIN ends e2 ON matches.id = m2.id AND e2.match_id = m2.id) AS played_ends_count,
    -- round num
    round_num,
    team_1_id,
    team_2_id,
    CASE WHEN matches.color_1 LIKE '%yellow%'
      THEN 'yellow'
    WHEN lower(matches.color_1) LIKE '%#ffc900%'
      THEN 'yellow'
    WHEN matches.color_1 LIKE '%#ffff00%'
      THEN 'yellow'
    WHEN matches.color_1 LIKE '%red%'
      THEN 'red'
    WHEN matches.color_1 LIKE '%#ff0000%'
      THEN 'red'
    WHEN matches.color_1 LIKE '%#ff6000%'
      THEN 'red'
    ELSE matches.color_1
    END
                                                                                       AS color1,
    CASE WHEN matches.color_2 LIKE '%yellow%'
      THEN 'yellow'
    WHEN lower(matches.color_2) LIKE '%#ffc900%'
      THEN 'yellow'
    WHEN matches.color_2 LIKE '%#ffff00%'
      THEN 'yellow'
    WHEN matches.color_2 LIKE '%red%'
      THEN 'red'
    WHEN matches.color_2 LIKE '%#ff0000%'
      THEN 'red'
    WHEN lower(matches.color_2) LIKE '%#ff6000%'
      THEN 'red'
    ELSE matches.color_2
    END
                                                                                       AS color2,
    rink,
    --- testing
    ends.end_num                                                                       AS end_num_test
  FROM tournaments
    INNER JOIN rounds
      ON rounds.tournament_id = tournaments.id
    INNER JOIN groups
      ON groups.round_id = rounds.id
    INNER JOIN matches
      ON matches.group_id = groups.id
    INNER JOIN team_instances
      ON (matches.team_1_id = team_instances.id)
    INNER JOIN teams
      ON teams.id = team_instances.team_id
    LEFT JOIN ends
      ON (matches.id = ends.match_id)
    LEFT JOIN (SELECT team_instances.id AS end_winner_id
               FROM team_instances) AS team_instances_3
      ON end_winner_id = ends.team_instance_id
    INNER JOIN match_configurations
      ON matches.match_configuration_id = match_configurations.id
    INNER JOIN (SELECT
                  team_score AS team_1_score,
                  *
                FROM scores) AS temp_scores
      ON temp_scores.m_id = matches.id AND matches.team_1_id = temp_scores.team_id
    INNER JOIN (SELECT
                  team_score AS opponent_score,
                  *
                FROM scores) AS temp_scores_2
      ON temp_scores_2.m_id = matches.id AND matches.team_2_id = temp_scores_2.team_id
    INNER JOIN (SELECT
                  team_score AS temp_team_1_score,
                  *
                FROM score_deltas) AS temp_score_deltas
      ON temp_score_deltas.m_id = matches.id AND temp_score_deltas.team_id = matches.team_1_id AND
         temp_score_deltas.end_num = ends.end_num
    INNER JOIN (SELECT
                  team_score AS temp_team_2_score,
                  *
                FROM score_deltas) AS temp_score_deltas_2
      ON temp_score_deltas_2.m_id = matches.id AND
         temp_score_deltas_2.team_id = matches.team_2_id AND
         temp_score_deltas_2.end_num = ends.end_num
    INNER JOIN (SELECT
                  team_instances."desc" AS opponent_name,
                  team_instances.id
                FROM team_instances) AS team_instances_2
      ON team_instances_2.id = matches.team_2_id
  WHERE --       tournaments.competition_id = 16 and tournaments.id = 199 AND
    ends.end_num > 0 AND matches.end_info_available = TRUE;


DROP VIEW MATCH_END_SCORES;

CREATE OR REPLACE VIEW MATCH_END_SCORES AS
  SELECT
    match,
    end_score,
    end_winner_id,
    team_1_id,
    team_1_won AS team_1_won_match
  FROM MATCH_ENDS
  --where end_score = 3
  --  where match = 14516
  GROUP BY match, end_score, end_winner_id, team_1_id, team_1_won;

-- computes the probablity of winning a game if we scored X in any end.
SELECT
  true_stmts,
  universe,
  true_stmts :: FLOAT / universe AS probability
FROM
  (SELECT count(match) AS universe
   FROM MATCH_END_SCORES
   WHERE end_score = 3) AS total,
  (SELECT count(match) AS true_stmts
   FROM MATCH_END_SCORES
   WHERE end_score = 3 AND ((end_winner_id = team_1_id AND team_1_won_match = 1) OR
                            (end_winner_id != team_1_id AND team_1_won_match = -1))) AS truth_
GROUP BY universe, true_stmts;


SELECT *
FROM MATCH_ENDS
WHERE match = 14510;
--where match = 1;

SELECT *
FROM team_instances
WHERE id = 4995;


SELECT
  --   CASE WHEN SUM(score) IS NULL THEN 0
  --   ELSE SUM(score)
  --   END as team_score,
  m.id        AS m_id,
  m.team_1_id AS m_team_1_id,
  e.*
FROM matches m
  INNER JOIN ends e ON m.team_1_id = e.team_instance_id AND e.match_id = m.id
WHERE m.team_1_id = 4995


SELECT *
FROM initiation_admins
  JOIN users ON user_id = users.id;
