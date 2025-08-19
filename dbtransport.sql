

---------------------------------------------------------------------------------------------------------------------

-- sales.t_dgn_whs_inventory definition

-- Drop table

-- DROP TABLE sales.t_dgn_whs_inventory;

CREATE TABLE sales.t_dgn_whs_inventory (
	id serial4 NOT NULL,
	line_id varchar NULL,
	partner_id int4 NULL,
	produkt_id int4 NULL,
	start_date date NULL,
	stop_date date NULL,
	is_reactivated bool NULL,
	angelegt_am timestamptz NULL DEFAULT now(),
	angelegt_von varchar NULL DEFAULT CURRENT_USER,
	bearbeitet_am timestamptz NULL,
	bearbeitet_von varchar NULL,
	auftraggeber_icc int4 NULL,
	"PRODUKTBEZEICHNUNG" varchar NULL,
	auftragseingangsdatum timestamp NULL,
	wunschdatum varchar NULL,
	strasse varchar NULL,
	hausnummer varchar NULL,
	plz varchar NULL,
	ort varchar NULL,
	ortsteil varchar NULL,
	portierungsdatum timestamp NULL,
	wowi_rabatt bool NULL,
	line_id_internal int4 NULL,
	CONSTRAINT t_dgn_whs_inventory_pk PRIMARY KEY (id),
	CONSTRAINT t_dgn_whs_inventory_un UNIQUE (line_id_internal)
);
CREATE UNIQUE INDEX t_dgn_whs_inventory_id_idx ON sales.t_dgn_whs_inventory USING btree (id, line_id);
CREATE UNIQUE INDEX t_dgn_whs_inventory_line_id_idx ON sales.t_dgn_whs_inventory USING btree (line_id);

-- Table Triggers

create trigger trg_dgn_metadataupdate before
update
    on
    sales.t_dgn_whs_inventory for each row execute function sales.ft_dgn_update_metadata();
create trigger trg_inventory_changes after
insert
    or
delete
    or
update
    on
    sales.t_dgn_whs_inventory for each row execute function sales.fn_log_inventory_changes();


-- sales.t_dgn_whs_inventory foreign keys

ALTER TABLE sales.t_dgn_whs_inventory ADD CONSTRAINT fk_t_dgn_whs_inventory FOREIGN KEY (partner_id) REFERENCES sales.t_dgn_whs_partner(id);
ALTER TABLE sales.t_dgn_whs_inventory ADD CONSTRAINT t_dgn_whs_inventory_t_dgn_whs_produkt_fk FOREIGN KEY (produkt_id) REFERENCES sales.t_dgn_whs_produkt(id);
ALTER TABLE sales.t_dgn_whs_inventory ADD CONSTRAINT t_dgn_whs_inventory_t_dgn_whs_produkt_fk3 FOREIGN KEY (line_id_internal) REFERENCES sales.t_dgn_whs_line_id_map(id);

---------------------------------------------------------------------------------------------------------------------

-- sales.t_dgn_whs_inventory_hist definition

-- Drop table

-- DROP TABLE sales.t_dgn_whs_inventory_hist;

CREATE TABLE sales.t_dgn_whs_inventory_hist (
	id serial4 NOT NULL,
	line_id varchar NULL,
	event_type_id int4 NULL,
	event_timestamp timestamptz NULL,
	alt_produkt_id int4 NULL,
	neu_produkt_id int4 NULL,
	kommentar varchar NULL,
	angelegt_am timestamptz NULL DEFAULT now(),
	angelegt_von varchar NULL DEFAULT CURRENT_USER,
	bearbeitet_am timestamptz NULL,
	bearbeitet_von varchar NULL,
	line_id_old varchar NULL,
	partner_id_old int4 NULL,
	produkt_id_old int4 NULL,
	start_date_old date NULL,
	stop_date_old date NULL,
	is_reactivated_old bool NULL,
	angelegt_am_old timestamptz NULL,
	angelegt_von_old varchar NULL,
	bearbeitet_am_old timestamptz NULL,
	bearbeitet_von_old varchar NULL,
	auftraggeber_icc_old int4 NULL,
	produktbezeichnung_old varchar NULL,
	auftragseingangsdatum_old varchar NULL,
	wunschdatum_old varchar NULL,
	strasse_old varchar NULL,
	hausnummer_old varchar NULL,
	plz_old varchar NULL,
	ort_old varchar NULL,
	ortsteil_old varchar NULL,
	portierungsdatum_old varchar NULL,
	partner_id int4 NULL,
	line_id_internal int4 NULL,
	line_id_internal_old int4 NULL,
	start_date date NULL,
	stop_date date NULL,
	CONSTRAINT t_dgn_whs_inventory_hist_pk PRIMARY KEY (id)
);

---------------------------------------------------------------------------------------------------------------------