
-- DROP FUNCTION public.total_score(m_id integer, end_id integer, team_id INTEGER) CASCADE ;

CREATE OR REPLACE FUNCTION total_score(m_id integer, team_id INTEGER) RETURNS BIGINT AS
$$
select
  CASE WHEN SUM(score) IS NULL THEN 0
  ELSE SUM(score)
  END
from matches inner join ends on matches.id = ends.match_id
where ends.team_instance_id = team_id and matches.id = m_id;
--where ends.team_instance_id = 4995 and matches.id = 14510;
$$ LANGUAGE SQL;


DROP VIEW MATCH_ENDS CASCADE ;

--
CREATE OR REPLACE VIEW MATCH_ENDS AS
  WITH scores as (select
                    CASE WHEN SUM(score) IS NULL THEN 0
                    ELSE SUM(score)
                    END as team_score,
                    m.id as m_id,
                    e.team_instance_id as team_id
                  from matches m
                    inner join ends e on e.match_id = m.id
                  GROUP BY m.id, e.team_instance_id),
    score_deltas as (select
                       CASE WHEN SUM(e2.score) IS NULL THEN 0
                       ELSE SUM(e2.score)
                       END as team_score,
                       m.id as m_id,
                       e.team_instance_id as team_id,
                       e.end_num
--                       , e2.end_num AS end_num_2, e2.score
                     from matches m
                       inner join ends e on e.match_id = m.id
                       INNER JOIN ends e2 on e2.match_id = m.id and e2.end_num <= e.end_num and e2.team_instance_id = e.team_instance_id
                     where m.id = 1
                     GROUP BY m.id, e.team_instance_id, e.id --, e2.id


    )
  SELECT tournaments.id as tourn_id,
    matches.id as Match,
    team_instances.id as team_instance_id,
    team_instances.desc as team_1_name,
    opponent_name,
    ends.end_num,
    ends.score as end_score,
    end_winner_id,
    -- team score for current match
    team_1_score,
    -- opponent team score for current match
    opponent_score,
    -- team 1 won or not
    CASE when team_1_score > opponent_score then 1
    WHEN team_1_score < opponent_score then -1
    ELSE 0
    END as team_1_won,
    -- team_1 score - team_2 score at the current end.
    score_delta,
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
    rink,
    --- testing
    ends.end_num as end_num_test
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
    LEFT JOIN (select team_instances.id as end_winner_id from team_instances) as team_instances_3
      ON end_winner_id = ends.team_instance_id
    INNER JOIN match_configurations
      on matches.match_configuration_id = match_configurations.id
    INNER JOIN (SELECT team_score as team_1_score, * from scores) as temp_scores
      on temp_scores.m_id = matches.id and matches.team_1_id = temp_scores.team_id
    INNER JOIN (SELECT team_score as opponent_score, * from scores) as temp_scores_2
      on temp_scores_2.m_id = matches.id and matches.team_2_id = temp_scores_2.team_id
    INNER JOIN (SELECT team_score as score_delta, * from scores where scores.end_num <= end_num_test) as temp_scores_3
      ON temp_scores_3.m_id = matches.id
    INNER JOIN (SELECT team_instances."desc" as opponent_name, team_instances.id
                from team_instances) as team_instances_2
      on team_instances_2.id = matches.team_2_id
  WHERE   --       tournaments.competition_id = 16 and tournaments.id = 199 AND
         ends.end_num > 0 AND matches.end_info_available = true
  ;



DROP VIEW MATCH_END_SCORES;

create or REPLACE view MATCH_END_SCORES as
  SELECT match, end_score, end_winner_id, team_1_id, team_1_won as team_1_won_match From MATCH_ENDS
  --where end_score = 3
  --  where match = 14516
  GROUP BY match, end_score, end_winner_id, team_1_id, team_1_won;


-- computes the probablity of winning a game if we scored X in any end.
select true_stmts, universe, true_stmts::FLOAT / universe as probability
from
  (SELECT count(match) as universe
                from MATCH_END_SCORES
                where end_score = 3) as total,
  (select count(match) as true_stmts
            FROM MATCH_END_SCORES
            where end_score = 3 and ((end_winner_id = team_1_id and team_1_won_match = 1) or
                                     (end_winner_id != team_1_id and team_1_won_match = -1))) as truth_
GROUP BY universe, true_stmts;



SELECT * From MATCH_ENDS
--where match = 14510;

select * FROM team_instances where id = 4995;


select
--   CASE WHEN SUM(score) IS NULL THEN 0
--   ELSE SUM(score)
--   END as team_score,
  m.id as m_id,
  m.team_1_id as m_team_1_id,
  e.*
from matches m
  inner join ends e on m.team_1_id = e.team_instance_id and e.match_id = m.id
where m.team_1_id = 4995
