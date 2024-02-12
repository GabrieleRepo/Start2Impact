/* DATA CLEANING */
 
/* Per prima cosa voglio creare una tabella countries che contiene i nomi di tutte le nazioni che verranno usate
 * per l'analisi. Parto confrontando le tabelle countriesrtegions e btscountrycodes
 */
-- Con questo codice confronto i campi delle due tabelle cercando di capire in quali nazioni esse differiscono
select *
from countriesregions c full outer join btscountrycodes b 
	on c.alpha_2 =b.code
where c.name is null or b.description is null;

/* Siccome la tabella countriesregions contiene più valori di btscountrycodes, prima copio tutti i campi della tabella 
 * countriesregions in countries e poi ci aggiungo i valori di btscountrycodes non inclusi in countriesregions */
create table countries as
select *
from countriesregions;

/* Aggiungo ora alla tabella countries i campi di btscountrycodes non presenti in countriesregions */
insert into countries (name, alpha_2)
select
	description, code
from btscountrycodes b left join countriesregions c 
	on b.code =c.alpha_2 
where c.name is null;

/* Il record "Serbia and Montenegro" è gia presente suddiviso in "Serbia" e "montenegro", perciò lo elimino */
delete from countries c 
where c.name= 'Serbia and Montenegro';

/* Controllo deathspercapita per vedere se ci sono nazioni non presenti in countries o scritte diversamente */
select d.validctrys 
from countries c full outer join deathspercapita d 
	on c.name = d.validctrys 
where c.name is null;

/* Siccome in deathspercapita ci sono nazioni scritte in maniera diversa da countries, creo una tabella deaths_pc_temp 
 * con i seguenti attributi e con i nomi delle nazioni corretti.
 * "Sint Maarten" è presente in countries col nome "Sint Maarten (Dutch part)" e "Saint Martin (French part)".
 *  Essendo scritto in olandese, lo rinomino da deathpercaspita in "Sint Maarten (Dutch part)". */

create table deaths_pc_temp as
select 
	validctrys as country_name,
	ntravelers as n_travelers,
	ndeaths as n_deaths,
	percap as pc
from deathspercapita d
where validctrys <>'NA'

-- Correggo i nomi con UPDATE
update deaths_pc_temp 
set country_name =
	case country_name
		when 'Sint Maarten' then 'Sint Maarten (Dutch part)'
		when 'Federated States of Micronesia' then 'Micronesia (Federated States of)'
		when 'British Virgin Islands' then 'Virgin Islands (British)'
		when 'The Bahamas' then 'Bahamas'
		when 'Curacao' then 'Curaçao'
		when 'Bonaire, Sint Eustatius, and Saba' then 'Bonaire, Sint Eustatius and Saba'
	end 
WHERE country_name IN ('Sint Maarten', 'Federated States of Micronesia', 'British Virgin Islands', 'The Bahamas', 'Curacao', 'Bonaire, Sint Eustatius, and Saba');

/* Faccio lo stesso procedimento per la tabella sdamerican_deaths_abroad con la tabella countries */
WITH countries_of_sdamerican_deaths_abroad AS (
    SELECT DISTINCT country
    FROM public.sdamerican_deaths_abroad
    ORDER BY country
)
SELECT
    coun.country,
    c.name
FROM 
    countries_of_sdamerican_deaths_abroad coun 
    LEFT JOIN countries c ON coun.country = c.name
WHERE 
    c.name IS NULL;

/* 
Ho ottenuto questi risultati:  
Abania è un errore e va corretto in Albania
Bosnia-Herzegovina con Bosnia and Herzegovina
British Virgin Islands con Virgin Islands (British)
Cabo Verde (formerly Cape Verde) con Cabo Verde
Federated States of Micronesia con Micronesia (Federated States of)
Jerusalem con Israel
Korea con South Korea
Kyrgyz Republic con Kyrgyzstan
Laos con Lao People's Democratic Republic
Macedonia con Macedonia (the former Yugoslav Republic of)
Micronesia con Micronesia (Federated States of)
Moldova con Moldova (Republic of)
Monrovia con Liberia 
Northern Ireland con United Kington
Slovak Republic con Slovakia
Tanzania con Tanzania, United Republic of
Turks and Caicos con Turks and Caicos Islands
UK con United Kingdom

Creo una tabella cause_of_deaths_temp correggendo i dati della tabella sdamerican_deaths_abroad */
create table cause_of_death_temp as
select 
	country as country_name,
	date,
	cause_of_death as motivation
from sdamerican_deaths_abroad sda

update cause_of_death_temp
set country_name =
case country_name
	when 'Abania' then 'Albania'
	when 'Bosnia-Herzegovina' then 'Bosnia and Herzegovina'
	when 'British Virgin Islands' then 'Virgin Islands (British)'
	when 'Cabo Verde (formerly Cape Verde)' then 'Cabo Verde'
	when 'Federated States of Micronesia' then 'Micronesia (Federated States of)'
	when 'Jerusalem' then 'Israel'
	when 'Korea' then 'South Korea'
	when 'Kyrgyz Republic' then 'Kyrgyzstan'
	when 'Laos' then 'Lao People''s Democratic Republic'
	when 'Macedonia' then  'Macedonia (the former Yugoslav Republic of)'
	when 'Micronesia' then 'Micronesia (Federated States of)'
	when 'Moldova' then 'Moldova (Republic of)'
	when 'Monrovia' then 'Liberia' 
	when 'Northern Ireland' then 'United Kington'
	when 'Slovak Republic' then 'Slovakia'
	when 'Tanzania' then 'Tanzania, United Republic of'
	when 'Turks and Caicos' then 'Turks and Caicos Islands'
	when 'UK' then 'United Kingdom'
end 
where country_name in ('Abania', 'Bosnia-Herzegovina', 'British Virgin Islands', 'Cabo Verde (formerly Cape Verde)',
'Federated States of Micronesia', 'Jerusalem', 'Korea', 'Kyrgyz Republic', 'Laos', 'Macedonia', 'Micronesia',
'Moldova', 'Monrovia', 'Northern Ireland', 'Slovak Republic', 'Tanzania', 'Turks and Caicos', 'UK');

/* Ora è il momento di analizzare la tabella btsoriginus. Selezionamo le colonne di interesse e controlliamo le sigle delle nazioni*/
-- Con questo codice controllo se ci sono nazioni di btsoriginus non presenti in country. (Vedrò che non ci sono in questo caso)
select 
	b.dest_country,
	c.alpha_2 
from btsoriginus b left join countries c
	on b.dest_country =c.alpha_2 
where c.alpha_2 is null;

/* Creo una tabella destinations_temp in cui voglio calcolare il numero di passeggeri statunitensi che nello stesso mese ed anno
   si sono diretti verso la stessa nazione*/
create table destinations_temp as(
select 
	dest_country,
	month,
	year,
	sum(passengers) as n_passengers
from btsoriginus 
group by dest_country, month, year
ORDER BY dest_country, year, month
);

/* Col seguente codice analizzo i nomi delle nazioni presenti in warningsranking non presenti in countries */
select
	w.sdwarnings_df_country
from warningsranking w full outer join countries c 
	on w.sdwarnings_df_country = c.name
where c.name is null

/* Ho ottenuto le seguenti nazioni: 
Cape Verde, Macedonia, Sint Maarten, Cote d'Ivoire, Tanzania, Reunion,
Federated States of Micronesia,
Falkland Islands,
Serbia and Montenegro,
Saint Helena, Ascension, and Tristan da Cunha,
British Virgin Islands,
The Bahamas,
Saint Martin,
Curacao,
Saint Barthelemy,
Laos,
Brunei,
Virgin Islands,
The Gambia,
Bonaire, Sint Eustatius, and Saba,
Macau,
Moldova
Vado a correggere i nomi di queste nazioni creando una tabella warnings_ranking_temp scegliendo solo le colonne di interesse da warningsranking */
create table warnings_ranking_temp as (
select 
	sdwarnings_df_country as country_name,
	sdwarnings_df_nwarnings as n_warnings
from warningsranking w)

update warnings_ranking_temp 
set country_name =
	case country_name
		when 'Cape Verde' then 'Cabo Verde'
		when 'Macedonia' then 'Macedonia (the former Yugoslav Republic of)'
		when 'Sint Maarten' then 'Sint Maarten (Dutch part)'
		when 'Cote d''Ivoire' then 'Côte d''Ivoire'
		when 'Tanzania' then 'Tanzania, United Republic of'
		when 'Reunion' then 'Réunion'
		when 'Federated States of Micronesia' then 'Micronesia (Federated States of)'
		when 'Falkland Islands' then 'Falkland Islands (Malvinas)'
		when 'Serbia and Montenegro' then 'Montenegro' --Serbia è già presente 
		when 'Saint Helena, Ascension, and Tristan da Cunha' then 'Saint Helena, Ascension and Tristan da Cunha'
		when 'British Virgin Islands' then 'Virgin Islands (British)'
		when 'The Bahamas' then 'Bahamas'
		when 'Saint Martin' then 'Saint Martin (French part)'
		when 'Curacao' then 'Curaçao'
		when 'Saint Barthelemy' then 'Saint Barthélemy'
		when 'Laos' then 'Lao People''s Democratic Republic'
		when 'Brunei' then 'Brunei Darussalam'
		when 'Virgin Islands' then 'Virgin Islands (U.S.)'
		when 'The Gambia' then 'Gambia'
		when 'Bonaire, Sint Eustatius, and Saba' then 'Bonaire, Sint Eustatius and Saba'
		when 'Macau' then 'Macao'
		when 'Moldova' then 'Moldova (Republic of)'
	end 
where country_name in ('Cape Verde', 'Macedonia', 'Sint Maarten', 'Cote d''Ivoire', 'Tanzania', 'Reunion',
'Federated States of Micronesia', 'Falkland Islands', 'Serbia and Montenegro', 'Saint Helena, Ascension, and Tristan da Cunha',
'British Virgin Islands', 'The Bahamas', 'Saint Martin', 'Curacao', 'Saint Barthelemy', 'Laos', 'Brunei',
'Virgin Islands', 'The Gambia', 'Bonaire, Sint Eustatius, and Saba', 'Macau', 'Moldova')

/* Ora elimino le colonne non utili e correggo i tipi di dati. Aggiungo anche una colonna che sarà la PK di countries*/
ALTER TABLE public.countries DROP COLUMN country_code;
ALTER TABLE public.countries DROP COLUMN iso_3166_2;
alter table public.countries add column id SERIAL;
ALTER TABLE public.countries ADD CONSTRAINT countries_pk PRIMARY KEY (id);
ALTER TABLE public.cause_of_death ALTER COLUMN "date" TYPE date USING "date"::date;

-- Modifico le tabelle temporanee prima create inserendo la colonna country_id al posto della colonna dei nomi delle nazioni
create table deaths_pc as
select 
	c.id as country_id,
	dp.n_travelers,
	dp.n_deaths,
	dp.pc 
from deaths_pc_temp dp left join countries c 
	on dp.country_name = c.name

create table destinations as
select 
	c.id as country_id,
	d.month,
	d.year,
	d.n_passengers 
from destinations_temp d left join countries c 
	on d.dest_country =c.alpha_2 

create table cause_of_death as
select 
	c.id as country_id,
	cod.date,
	cod.motivation 
from cause_of_death_temp cod left join countries c 
	on cod.country_name  =c.name

create table warnings_ranking as
select 
	c.id as country_id,
	wr.n_warnings 
from warnings_ranking_temp wr left join countries c 
	on wr.country_name =c.name

-- Ora ho le tabelle ripulite, perciò elimino tutte quelle di partenza e quelle temporanee

-- Creo diagramma ER delle tabelle rimanenti. Successivamente posso iniziare l'analisi
ALTER TABLE public.deaths_pc ADD CONSTRAINT deaths_pc_fk FOREIGN KEY (country_id) REFERENCES public.countries(id);
ALTER TABLE public.warnings_ranking ADD CONSTRAINT warnings_ranking_fk FOREIGN KEY (country_id) REFERENCES public.countries(id);
ALTER TABLE public.destinations ADD CONSTRAINT destinations_fk FOREIGN KEY (country_id) REFERENCES public.countries(id);
ALTER TABLE public.cause_of_death ADD CONSTRAINT cause_of_death_fk FOREIGN KEY (country_id) REFERENCES public.countries(id);

/* DATA ANALYSIS */

-- Top 10 destinazioni
select 
	c.name,
	sum(d.n_passengers) as total_travelers
from destinations d inner join countries c 
	on d.country_id = c.id 
group by c.name
order by total_travelers desc
limit 10;

-- Top 10 continenti
select 
	c.region,
	sum(d.n_passengers) as total_travelers
from destinations d inner join countries c 
	on d.country_id = c.id 
group by c.region
order by total_travelers desc;

-- Top 10 sub-regioni
select 
	c.sub_region,
	sum(d.n_passengers) as total_travelers
from destinations d inner join countries c 
	on d.country_id = c.id 
group by c.sub_region
order by total_travelers desc
limit 10;

-- Calcolo della variazione percentuale dei viaggiatori negli anni
SELECT 
    d.year,
    SUM(d.n_passengers) AS total_travelers,
    100 * (SUM(d.n_passengers) - FIRST_VALUE(SUM(d.n_passengers)) OVER (ORDER BY d.year ASC ROWS BETWEEN 1 PRECEDING AND current ROW)) / FIRST_VALUE(SUM(d.n_passengers)) OVER (ORDER BY d.year ASC ROWS BETWEEN 1 PRECEDING AND current ROW) AS variazione_percentuale
FROM 
    destinations d
GROUP BY 
    d.year
ORDER BY 
    d.year;

-- Top 10 nazioni con pc alto
select 
	c.name,
	dp.n_travelers,
	dp.n_deaths,
	dp.pc 
from countries c inner join deaths_pc dp 
	on C.id = DP.country_id
order by dp.pc desc 
limit 10;

-- Top 10 nazioni con pc basso (Siccome sono molte, voglio concentrarmi su quelle aventi più turisti e più morti)
select 
	c.name,
	dp.n_travelers,
	dp.n_deaths,
	dp.pc 
from countries c inner join deaths_pc dp 
	on C.id = DP.country_id
order by dp.pc asc, dp.n_travelers desc, DP.n_deaths desc
limit 10;

-- Cause di morte più comuni
select 
	cod.motivation,
	count(*) as deaths
from cause_of_death cod 
group by cod.motivation
order by deaths desc 

 -- Dall'analisi si può vedere come la stessa causa di morte è scritta in maniera diversa. Cerco di standardizzarle
-- Update Auto
update cause_of_death 
set motivation = 'Vehicle Accident - Auto'
where motivation like '%Auto%'	
-- Update Other
update cause_of_death 
set motivation = 'Vehicle Accident - Other'
where motivation like '%Other'	
-- Update Motorcycle
update cause_of_death 
set motivation = 'Vehicle Accident - Motorcycle'
where motivation like '%otorcy%'
-- Update Pedestrian
update cause_of_death 
set motivation = 'Vehicle Accident - Pedestrian'
where motivation like '%edest%'	
-- Update Bus
update cause_of_death 
set motivation = 'Vehicle Accident - Bus'
where motivation like '%Bus'
-- Update Train
update cause_of_death 
set motivation = 'Vehicle Accident - Train'
where motivation like '%Train'
-- Update Bike
update cause_of_death 
set motivation = 'Vehicle Accident - Bike'
where motivation like '%bike'
-- Update Other Accident
update cause_of_death 
set motivation = 'Other Accident'
where motivation like 'Other%'
-- Update Homicide
update cause_of_death 
set motivation = 'Homicide'
where motivation like '%omicide'

-- Eseguo di nuovo il codice scritto precedentemente per vedere le cause di morte più frequenti

-- Cause di morte più frequenti nelle 10 nazioni con tasso di mortalità pro capite alto
select
	c.name,
	cod.motivation,
	count(*) as counter
from deaths_pc dp inner join cause_of_death cod 
	on dp.country_id = cod.country_id inner join countries c 
		on c.id = dp.country_id 
where dp.country_id in (
	select 
		dp.country_id 
	from deaths_pc dp 
	order by dp.pc desc 
	limit 10
	)
group by 
	c.name, 
	cod.motivation 
order by c.name, counter desc;

-- Top 10 nazioni per numero di avvisi di viaggio
select 
	c.name,
	n_warnings 
from warnings_ranking wr inner join countries c 
	on wr.country_id =c.id 
limit 10;

-- Voglio creare una tabella con i nomi delle nazioni, il rank in base al tasso di mortalità pro capite, il rank per i warnings e un rank finale che tiene conto di entrambi
WITH pc_ranking AS (
	SELECT 
		country_id,
		pc,
		RANK() OVER (ORDER BY pc DESC) AS ranking_pc
	FROM deaths_pc
), 
warning_ranking AS (
	SELECT 
		country_id,
		n_warnings,
		RANK() OVER (ORDER BY n_warnings DESC) AS ranking_warning
	FROM warnings_ranking
)
SELECT 
	c.name,
	pc_ranking.ranking_pc,
	warning_ranking.ranking_warning,
	RANK() OVER (ORDER BY pc_ranking.ranking_pc + warning_ranking.ranking_warning) AS final_rank
FROM pc_ranking 
INNER JOIN warning_ranking ON pc_ranking.country_id = warning_ranking.country_id inner join countries c on c.id = pc_ranking.country_id;