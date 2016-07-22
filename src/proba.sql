
DROP  FUNCTION public.total_score(m_id integer, end_id integer, team_id INTEGER) CASCADE ;

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

select total_score(14510, 12, 4995);

DROP VIEW MATCH_ENDS;

CREATE OR REPLACE VIEW MATCH_ENDS AS
            SELECT tournaments.id as tourn_id, matches.id as Match,
                   team_instances.id as team_instance_id,
                   team_instances.desc as equipes,
                   ends.end_num,
              -- team score for current match
              (select total_score(matches.id, matches.team_1_id)) as team_score,
              -- opponent team score for current match
              (select total_score(matches.id, matches.team_2_id)) as opponent_score,
              -- won or not
              CASE when total_score(matches.id, matches.team_1_id) > total_score(matches.id, matches.team_2_id) then 1
              WHEN total_score(matches.id, matches.team_1_id) = total_score(matches.id, matches.team_2_id) then 0
              ELSE -1
              END as won,
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
                   rink
            FROM tournaments
                 INNER JOIN rounds ON rounds.tournament_id = tournaments.id
                 INNER JOIN groups ON groups.round_id = rounds.id
                 INNER JOIN matches ON matches.group_id = groups.id
                 INNER JOIN team_instances ON (matches.team_1_id = team_instances.id)
                 INNER JOIN teams ON teams.id = team_instances.team_id
                 LEFT JOIN ends ON (matches.id = ends.match_id)
                 INNER JOIN match_configurations on matches.match_configuration_id = match_configurations.id
            WHERE tournaments.competition_id = 16 AND ends.end_num > 0 AND matches.end_info_available = true;

SELECT * From MATCH_ENDS
where match = 14510;

select * FROM team_instances where id = 4995;