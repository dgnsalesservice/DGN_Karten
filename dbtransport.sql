----------------------------------------------------------------------------------------------------------------------------------------------------

-- dgn_cso_ame.t_dgn_bigpm_agentur_status definition

-- Drop table

-- DROP TABLE dgn_cso_ame.t_dgn_bigpm_agentur_status;

CREATE TABLE dgn_cso_ame.t_dgn_bigpm_agentur_status (
	id serial4 NOT NULL,
	status varchar NOT NULL,
	angelegt_von varchar NOT NULL DEFAULT CURRENT_USER,
	angelegt_am timestamptz NOT NULL DEFAULT now(),
	bearbeitet_von varchar NULL,
	bearbeitet_am timestamptz NULL,
	CONSTRAINT t_dgn_bigpm_agentur_status_pk PRIMARY KEY (id)
);

-- Table Triggers

create trigger trg_dgn_metadataupdate before
update
    on
    dgn_cso_ame.t_dgn_bigpm_agentur_status for each row execute function dgn_cso_ame.ft_dgn_update_metadata();

----------------------------------------------------------------------------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION dgn_cso_ame.log_agentur_spid_changes()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$
DECLARE
    v_agentur_name TEXT;
    v_bemerkung TEXT;
BEGIN
    -- Für die Tabelle dgn_cso_ame.t_dgn_bigpm_agenturen_spids
    IF TG_TABLE_NAME = 't_dgn_bigpm_agenturen_spids' THEN
        IF OLD.agentur_id IS NOT NULL THEN
            SELECT agentur, bemerkung INTO v_agentur_name, v_bemerkung
            FROM dgn_cso_ame.t_dgn_bigpm_agenturen
            WHERE id = OLD.agentur_id;
        END IF;

        IF TG_OP = 'UPDATE' THEN
            IF (OLD.agentur_id IS DISTINCT FROM NEW.agentur_id OR
                OLD.subproject_id IS DISTINCT FROM NEW.subproject_id OR
                OLD.vvm IS DISTINCT FROM NEW.vvm OR
                OLD.bvm IS DISTINCT FROM NEW.bvm OR
                OLD."start" IS DISTINCT FROM NEW."start" OR
                OLD."ende" IS DISTINCT FROM NEW."ende") THEN

                INSERT INTO dgn_cso_ame.t_dgn_bigpm_agenturen_hist (
                    agentur_id, spid_id,
                    agentur_id_old, spid_id_old,
                    agentur, bemerkung, bemerkung_old,
                    vvm, vvm_old, bvm, bvm_old,
                    "start", start_old, "ende", ende_old,
                    bearbeitet_am)
                VALUES (
                    NEW.agentur_id, NEW.subproject_id,
                    OLD.agentur_id, OLD.subproject_id,
                    v_agentur_name,
                    v_bemerkung, v_bemerkung, -- Die Bemerkung bleibt unverändert, da sie nicht in spids geändert wird
                    NEW.vvm, OLD.vvm,
                    NEW.bvm, OLD.bvm,
                    NEW."start", OLD."start",
                    NEW."ende", OLD."ende",
                    CURRENT_TIMESTAMP
                );
            END IF;
        ELSIF TG_OP = 'DELETE' THEN
            INSERT INTO dgn_cso_ame.t_dgn_bigpm_agenturen_hist (
                agentur_id, spid_id,
                agentur_id_old, spid_id_old,
                agentur, bemerkung, bemerkung_old,
                vvm, vvm_old, bvm, bvm_old,
                "start", start_old, "ende", ende_old,
                bearbeitet_am)
            VALUES (
                OLD.agentur_id, OLD.subproject_id,
                OLD.agentur_id, OLD.subproject_id,
                v_agentur_name,
                v_bemerkung, v_bemerkung,
                OLD.vvm, OLD.vvm,
                OLD.bvm, OLD.bvm,
                OLD."start", OLD."start",
                OLD."ende", OLD."ende",
                CURRENT_TIMESTAMP
            );
        END IF;

    -- Für die Tabelle dgn_cso_ame.t_dgn_bigpm_agenturen
    ELSIF TG_TABLE_NAME = 't_dgn_bigpm_agenturen' THEN
        IF TG_OP = 'UPDATE' THEN
            IF OLD.status_id IS DISTINCT FROM NEW.status_id OR
               OLD.bemerkung IS DISTINCT FROM NEW.bemerkung OR
               OLD.email IS DISTINCT FROM NEW.email OR
               OLD.kreditor_nr IS DISTINCT FROM NEW.kreditor_nr OR
               OLD.firmennamenzusatz IS DISTINCT FROM NEW.firmennamenzusatz OR
               OLD.rechtsform IS DISTINCT FROM NEW.rechtsform OR
               OLD.umsatzsteuer_id IS DISTINCT FROM NEW.umsatzsteuer_id OR
               OLD.hrahrb_regnr IS DISTINCT FROM NEW.hrahrb_regnr OR
               OLD.iban IS DISTINCT FROM NEW.iban OR
               OLD.ust_pflichtig IS DISTINCT FROM NEW.ust_pflichtig THEN

                INSERT INTO dgn_cso_ame.t_dgn_bigpm_agenturen_hist (
                    agentur_id, status_id_agentur,
                    status_id_agentur_old,
                    agentur, bemerkung, bemerkung_old,
                    email, email_old, kreditor_nr, kreditor_nr_old,
                    firmennamenzusatz, firmennamenzusatz_old, rechtsform, rechtsform_old,
                    umsatzsteuer_id, umsatzsteuer_id_old, hrahrb_regnr, hrahrb_regnr_old,
                    iban, iban_old, ust_pflichtig, ust_pflichtig_old,
                    bearbeitet_am)
                VALUES (
                    NEW.id, NEW.status_id, OLD.status_id,
                    NEW.agentur,
                    NEW.bemerkung, OLD.bemerkung,
                    NEW.email, OLD.email,
                    NEW.kreditor_nr, OLD.kreditor_nr,
                    NEW.firmennamenzusatz, OLD.firmennamenzusatz,
                    NEW.rechtsform, OLD.rechtsform,
                    NEW.umsatzsteuer_id, OLD.umsatzsteuer_id,
                    NEW.hrahrb_regnr, OLD.hrahrb_regnr,
                    NEW.iban, OLD.iban,
                    NEW.ust_pflichtig, OLD.ust_pflichtig,
                    CURRENT_TIMESTAMP
                );
            END IF;
        END IF;
    END IF;

    RETURN NEW;
END;
$function$
;

----------------------------------------------------------------------------------------------------------------------------------------------------

-- dgn_cso_ame.t_dgn_bigpm_agenturen definition

-- Drop table

-- DROP TABLE dgn_cso_ame.t_dgn_bigpm_agenturen;

CREATE TABLE dgn_cso_ame.t_dgn_bigpm_agenturen (
	id serial4 NOT NULL,
	agentur varchar NOT NULL,
	email varchar NULL,
	status_id int4 NULL,
	kopf_id int4 NULL,
	gigasales_id int4 NULL,
	kreditor_nr varchar NULL,
	"lead" varchar NULL,
	gueltig_fuer_gates varchar NULL,
	strasse varchar NULL,
	hausnummer int4 NULL,
	hausnummer_suffix varchar NULL,
	plz varchar NULL,
	ort varchar NULL,
	angelegt_von varchar NOT NULL DEFAULT CURRENT_USER,
	angelegt_am timestamptz NOT NULL DEFAULT now(),
	bearbeitet_von varchar NULL,
	bearbeitet_am timestamptz NULL,
	bemerkung varchar(50) NULL,
	firmennamenzusatz varchar NULL,
	rechtsform varchar NULL,
	umsatzsteuer_id varchar NULL,
	hrahrb_regnr varchar NULL,
	iban varchar NULL,
	ust_pflichtig bool NULL,
	partnerart varchar NULL,
	gueltig_ab varchar NULL,
	gueltig_bis varchar NULL,
	schufa_score int4 NULL,
	kontoinhaber varchar NULL,
	ansprechpartner varchar NULL,
	kred_nr_sap varchar NULL,
	keine_zsmarbeit bool NULL,
	zahlsperre bool NULL,
	abrechnungssperre bool NULL,
	ansprechpartner_email varchar NULL,
	CONSTRAINT t_dgn_bigpm_agentur_pk PRIMARY KEY (id),
	CONSTRAINT t_dgn_bigpm_agenturen_un UNIQUE (agentur)
);

-- Table Triggers

create trigger trg_dgn_metadataupdate before
update
    on
    dgn_cso_ame.t_dgn_bigpm_agenturen for each row execute function dgn_cso_ame.ft_dgn_update_metadata();
create trigger trigger_log_agentur_status_changes after
update
    on
    dgn_cso_ame.t_dgn_bigpm_agenturen for each row execute function dgn_cso_ame.log_agentur_spid_changes();

----------------------------------------------------------------------------------------------------------------------------------------------------

-- sales.t_dgn_bigpm_agenturen_hist definition

-- Drop table

-- DROP TABLE sales.t_dgn_bigpm_agenturen_hist;

CREATE TABLE sales.t_dgn_bigpm_agenturen_hist (
	id serial4 NOT NULL,
	agentur_id int4 NOT NULL,
	agentur varchar NOT NULL,
	status_id_agentur int4 NULL,
	status_id_agentur_old int4 NULL,
	spid_id int4 NULL,
	spid_id_old int4 NULL,
	bemerkung varchar NULL,
	bemerkung_old varchar NULL,
	angelegt_von varchar NOT NULL DEFAULT CURRENT_USER,
	angelegt_am timestamptz NOT NULL DEFAULT now(),
	bearbeitet_von varchar NULL,
	bearbeitet_am timestamptz NULL,
	agentur_id_old int4 NULL,
	email varchar NULL,
	email_old varchar NULL,
	kreditor_nr varchar NULL,
	kreditor_nr_old varchar NULL,
	firmennamenzusatz varchar NULL,
	firmennamenzusatz_old varchar NULL,
	rechtsform varchar NULL,
	rechtsform_old varchar NULL,
	umsatzsteuer_id varchar NULL,
	umsatzsteuer_id_old varchar NULL,
	hrahrb_regnr varchar NULL,
	hrahrb_regnr_old varchar NULL,
	iban varchar NULL,
	iban_old varchar NULL,
	ust_pflichtig bool NULL,
	ust_pflichtig_old bool NULL,
	vvm bool NULL,
	vvm_old bool NULL,
	bvm bool NULL,
	bvm_old bool NULL,
	"start" varchar NULL,
	start_old varchar NULL,
	ende varchar NULL,
	ende_old varchar NULL,
	CONSTRAINT t_dgn_bigpm_agenturen_hist_pk PRIMARY KEY (id)
);

-- Table Triggers

create trigger trg_dgn_metadataupdate before
update
    on
    sales.t_dgn_bigpm_agenturen_hist for each row execute function sales.ft_dgn_update_metadata();

----------------------------------------------------------------------------------------------------------------------------------------------------

-- sales.t_dgn_bigpm_agenturen_spids definition

-- Drop table

-- DROP TABLE sales.t_dgn_bigpm_agenturen_spids;

CREATE TABLE sales.t_dgn_bigpm_agenturen_spids (
	id serial4 NOT NULL,
	agentur_id int4 NULL,
	subproject_id int4 NULL,
	vvm bool NULL,
	bvm bool NULL,
	"start" varchar NULL,
	ende varchar NULL,
	angelegt_von varchar NOT NULL DEFAULT CURRENT_USER,
	angelegt_am timestamptz NOT NULL DEFAULT now(),
	bearbeitet_von varchar NULL,
	bearbeitet_am timestamptz NULL,
	zeitraum varchar(50) NULL,
	CONSTRAINT t_dgn_bigpm_agenturen_spids_pk PRIMARY KEY (id)
);

-- Table Triggers

create trigger trg_dgn_metadataupdate before
update
    on
    sales.t_dgn_bigpm_agenturen_spids for each row execute function sales.ft_dgn_update_metadata();
create trigger trigger_log_agentur_spid_changes after
delete
    or
update
    on
    sales.t_dgn_bigpm_agenturen_spids for each row execute function sales.log_agentur_spid_changes();


-- sales.t_dgn_bigpm_agenturen_spids foreign keys

ALTER TABLE sales.t_dgn_bigpm_agenturen_spids ADD CONSTRAINT t_dgn_bigpm_agenturen_spids_fk FOREIGN KEY (agentur_id) REFERENCES sales.t_dgn_bigpm_agenturen(id);

----------------------------------------------------------------------------------------------------------------------------------------------------



----------------------------------------------------------------------------------------------------------------------------------------------------