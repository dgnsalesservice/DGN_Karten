import psycopg2
import subprocess
import json
from config import DB_PARAMS_prod
from config_dev import DB_PARAMS_dev

# Verbindung zur Datenbank
conn_prod = psycopg2.connect(**DB_PARAMS_prod)
conn_dev = psycopg2.connect(**DB_PARAMS_dev)

def fetch_geojson_db(sp_id=None, p_id=None):
    if sp_id:
        where_clause = "teilprojekt_id = %s"
        value = sp_id
    elif p_id:
        where_clause = "projekt_id = %s"
        value = p_id
    else:
        return {}

    query = f"""
    SELECT json_build_object(
        'type', 'FeatureCollection',
        'features', json_agg(
            json_build_object(
                'type', 'Feature',
                'geometry', geo,
                'properties', json_build_object('dgn_phase', dgn_phase)
            )
        )
    ) AS geojson
    FROM (
        SELECT ST_AsGeoJSON(ST_Transform(geom, 4326))::json AS geo, dgn_phase
        FROM gis_planung.dgn_phase
        WHERE {where_clause} AND dgn_phase IN ('1', '2')
    ) t;
    """

    with conn_prod.cursor() as cursor:
        cursor.execute(query, (value,))
        result = cursor.fetchone()
    return result[0] if result else {}

def update_table(geojson, subprojekt_id=None, projekt_id=None):
    with conn_dev.cursor() as cursor:
        if subprojekt_id:
            cursor.execute("""
                UPDATE dgn_cso_ame.t_dgn_create_map
                SET geojson = %s, created = TRUE
                WHERE subprojekt_id = %s
            """, (geojson, subprojekt_id))
        elif projekt_id:
            cursor.execute("""
                UPDATE dgn_cso_ame.t_dgn_create_map
                SET geojson = %s, created = TRUE
                WHERE project_id = %s
            """, (geojson, projekt_id))
        conn_dev.commit()

def create_or_update_file(file_path, content):
    with open(file_path, "w", encoding="utf-8") as f:
        f.write(content)

def git_add_commit_push(commit_message, file_path):
    subprocess.run(["git", "add", "--all"], check=True)
    subprocess.run(["git", "commit", "--allow-empty", "-m", commit_message], check=True)
    subprocess.run(["git", "push", "--set-upstream", "origin", "main"], check=True)

with conn_dev.cursor() as cursor:
    cursor.execute("""
        SELECT DISTINCT 
            COALESCE(subprojekt_id::text, ''), 
            COALESCE(project_id::text, '')
        FROM dgn_cso_ame.v_dgn_create_map 
        WHERE subprojekt_id IS NOT NULL OR project_id IS NOT NULL;
    """)
    eintraege = cursor.fetchall()

for sp_id_raw, p_id_raw in eintraege:
    sp_id = int(sp_id_raw) if sp_id_raw not in (None, '', 'None') else None
    p_id = int(p_id_raw) if p_id_raw not in (None, '', 'None') else None

    if sp_id is not None:
        identifier = f"sp_{sp_id}"
    elif p_id is not None:
        identifier = f"p_{p_id}"
    else:
        identifier = "unknown"

    file_path = f"{identifier}.html"

    try:
        geojson_data = fetch_geojson_db(sp_id=sp_id, p_id=p_id)
        geojson_str = json.dumps(geojson_data)
        geojson_str_single = geojson_str.replace('"', "'")
    except Exception as e:
        print(f"❌ GeoJSON für {identifier} konnte nicht geladen werden:", e)
        continue

    lats, lngs = [], []
    try:
        for feature in geojson_data['features']:
            geometry = feature['geometry']
            coords = geometry['coordinates']
            if geometry['type'] == 'MultiPolygon':
                for polygon in coords:
                    for ring in polygon:
                        for lon, lat in ring:
                            lats.append(lat)
                            lngs.append(lon)
            elif geometry['type'] == 'Polygon':
                for ring in coords:
                    for lon, lat in ring:
                        lats.append(lat)
                        lngs.append(lon)
            elif geometry['type'] == 'Point':
                lon, lat = coords
                lats.append(lat)
                lngs.append(lon)
        center_lat = sum(lats) / len(lats)
        center_lon = sum(lngs) / len(lngs)
    except:
        print(f"⚠️ Keine gültigen Koordinaten – ID {identifier}")
        continue

    content = f"""
                    <!DOCTYPE html>
                <html lang="en">
                <head>
                    <meta charset="utf-8">
                    <meta name="viewport" content="width=device-width, initial-scale=1">
                    <title>Karte {identifier} </title>
                    <link rel="stylesheet" href="https://unpkg.com/leaflet@1.9.4/dist/leaflet.css" />
                    <script src="https://unpkg.com/leaflet@1.9.4/dist/leaflet.js"></script>
                    <script src="https://unpkg.com/leaflet-control-geocoder/dist/Control.Geocoder.js"></script>
                    <link href="https://cdnjs.cloudflare.com/ajax/libs/font-awesome/6.0.0-beta3/css/all.min.css" rel="stylesheet">
                    <link href="https://fonts.googleapis.com/css2?family=Montserrat:wght@400;600&display=swap" rel="stylesheet">
                    <style>
                        html, body {{
                            height: 100%;
                            margin: 0;
                        }}
                        .leaflet-container {{
                            height: 100%;
                            width: 100%;
                            max-width: 100%;
                            max-height: 100%;
                        }}
                        .leaflet-control-zoom {{
                            background: none !important;
                            box-shadow: none !important;
                            border: none !important;
                        }}

                        /*+ und - button formatierung*/
                        .leaflet-control-zoom-in, .leaflet-control-zoom-out {{
                            background-color: white !important; /*hintergrundfarbe*/
                            color: grey !important; /*button farbe*/
                            border: none !important; /*keine umrandung*/
                            width: 30px;
                            height: 30px;
                            display: flex;
                            justify-content: center;
                            align-items: center;
                            font-size: 15px; /*symbolgröße*/
                            font-weight: 20;
                            font-family: 'Montserrat', sans-serif; /*dgn font*/
                            box-shadow: 0 1px 3px rgba(0, 0, 0, 0.3); /*schatten*/
                        }}

                        .leaflet-control-zoom-in:hover, .leaflet-control-zoom-out:hover {{
                            background-color: #f0f0f0 !important; /* hover maus effekt */
                        }}
                        /*zurück zu ausgangskarte zoomen button formatieren*/
                        .custom-control {{
                            position: absolute;
                            bottom: -40px;
                            left:0px;
                            background: white;
                            padding: 5px;
                            border-radius: 2px;
                            box-shadow: 0 1px 3px rgba(0, 0, 0, 0.3);
                            cursor: pointer;
                            display: flex;
                            justify-content: center;
                            align-items: center;
                            width: 20px;
                            height: 20px;
                            color: grey
                        }}

                        /*legenden button formatieren*/
                        .custom-control2 {{
                            position: absolute;
                            bottom: -320px;
                            left: 0px;
                            background: white;
                            padding: 5px;
                            border-radius:2px;
                            box-shadow: 0 1px 3px rgba(0, 0, 0, 0.3);
                            cursor: pointer;
                            display: flex;
                            justify-content: center;
                            align-items: center;
                            width: 20px;
                            height: 20px;
                            color: grey
                        }}
                        .custom-control:hover, .custom-control2:hover {{
                            background-color: #f0f0f0 !important;
                        }}
                            /* formatieren suchen button */
                        .leaflet-control-geocoder-icon {{
                            background-color: white !important;
                            color: grey !important;
                            border: none !important;
                            width: 20px;
                            height: 20px;
                            display: flex;
                            justify-content: center;
                            align-items: center;
                            font-size: 15px;
                            font-family: 'Montserrat', sans-serif;
                            box-shadow: 0 1px 3px rgba(0, 0, 0, 0.3);
                            border-radius: 2px;
                            cursor: pointer;
                        }}
                        .leaflet-control-geocoder-icon:hover {{
                            background-color: #f0f0f0 !important;
                        }}

                        /*formatieren grauer marker*/
                        .custom-marker {{
                            width: 15px;
                            height: 15px;
                            background-color: grey;
                            border-radius: 50%;
                            border: 1px solid white;
                        }}
                        /*legende formatieren*/
                        #legend {{
                            position: absolute;
                            bottom: 80px;
                            left: 55px;
                            display: none;
                            z-index: 1000;
                            background: white;
                            padding: 10px;
                            border-radius: 5px;
                            box-shadow: 0px 2px 5px rgba(0, 0, 0, 0.2);
                            font-family: 'Montserrat', sans-serif;
                        }}

                        #legend div {{
                            font-size: 12px;
                            line-height: 18px;
                        }}
                        .grayscale-tile {{
                        filter: grayscale(100%);
                        }}
                    </style>
                      <link rel="stylesheet" href="https://unpkg.com/leaflet-control-geocoder/dist/Control.Geocoder.css" />
                </head>
                <body>
                <div id="map"></div>
                <div id="legend">
                    <div><span style="display:inline-block; width:20px; height:10px; background:#FF7F00; margin-right:5px;"></span>Ausbauphase 1: Ausbau bei ausreichender Nachfrage</div>
                    <div><span style="display:inline-block;width:20px; height:10px; background:#00143C; margin-right:5px;"></span>Ausbauphase 2: Interessenbekundung möglich</div>
                </div>
                <script>
                    const initialCoordinates = [{center_lat}, {center_lon}];
                    const initialZoomLevel = 13;

                    const map = L.map('map',{{
                    zoomControl: false //default zoom - + rausnehmen
                }}).setView(initialCoordinates, initialZoomLevel);


                    const grayscaleOSM = L.tileLayer('https://{{s}}.tile.openstreetmap.org/{{z}}/{{x}}/{{y}}.png', {{
                        attribution: '&copy; OpenStreetMap contributors',
                        maxZoom: 19,
                        className: 'grayscale-tile'
                    }}).addTo(map);;

                    L.control.zoom({{
                        position: 'topleft'
                    }}).addTo(map);

                    const geoJsonData = {geojson_data};

                    const geoLayer = L.geoJSON(geoJsonData, {{
                        style: feature => {{
                            if (feature.properties.dgn_phase === 2) {{
                                return {{ stroke: false, fillColor: '#00143C', fillOpacity: 0.6 }};
                            }} else {{
                                return {{ stroke: false, fillColor: '#FF7F00', fillOpacity: 0.6 }};
                            }}
                        }}
                    }});

                    geoLayer.addTo(map);
                   // map.fitBounds(geoLayer.getBounds());

                    //button der auf ausgangskarte zurück zoomt auf karte bringen
                    const zoomFullExtentControl = L.Control.extend({{
                        options: {{ position: 'topleft' }},
                        onAdd: function () {{
                            const container = L.DomUtil.create('div', 'custom-control');
                            container.innerHTML = '<i class="fas fa-home"></i>';
                            L.DomEvent.on(container, 'click', () => map.setView(initialCoordinates, initialZoomLevel));
                            return container;
                        }}
                    }});
                    map.addControl(new zoomFullExtentControl());

                    //legende button auf karte bringen
                    const legendControl = L.Control.extend({{
                        options: {{ position: 'topleft' }},
                        onAdd: function () {{
                            const container = L.DomUtil.create('div', 'custom-control2');
                            container.innerHTML = '<i class="fas fa-list"></i>';
                            L.DomEvent.on(container, 'click', () => {{
                                const legend = document.getElementById('legend');
                                legend.style.display = legend.style.display === 'none' ? 'block' : 'none';
                            }});
                            return container;
                        }}
                    }});
                    map.addControl(new legendControl());

                    const markerLayerGroup = L.layerGroup().addTo(map);

                    //grauer kreis als marker
                    const geocoder = L.Control.geocoder({{
                        defaultMarkGeocode: false //default rausnehmen
                    }})
                        .on('markgeocode', function (e) {{
                            //existierende marker löschen
                            markerLayerGroup.clearLayers();

                            const latlng = e.geocode.center;

                            //grauer kreis als custom marker
                            const customMarker = L.divIcon({{
                                className: 'custom-marker'
                            }});

                            const marker = L.marker(latlng, {{ icon: customMarker }});
                            markerLayerGroup.addLayer(marker);

                            //zoom auf ausgewählte adresse
                            map.setView(latlng, 14);
                        }})
                        .addTo(map);

                </script>
                </body>
                </html>
                    """

    create_or_update_file(file_path, content)

    try:
        git_add_commit_push(f"Karte für {identifier} erstellt", file_path)
        update_table(geojson_str_single, subprojekt_id=sp_id, projekt_id=p_id)
        id_column = "subprojekt_id" if sp_id else "project_id"
        id_value = sp_id if sp_id else p_id
        with conn_dev.cursor() as cursor:
            cursor.execute(f"SELECT DISTINCT angelegt_von FROM dgn_cso_ame.t_dgn_create_map WHERE {id_column} = %s", (id_value,))
            empfaenger = [r[0] for r in cursor.fetchall()]
            print(f"""
            E-Mail an: {empfaenger}
            iframe-Snippet für {id_column} {id_value}:
            <iframe src="https://dgnsalesservice.github.io/DGN_Karten/{file_path}"
            style="width: 100%; height: 100%; border: none; position: absolute; top: 0; left: 0"></iframe>
            """)

    except Exception as e:
        print("❌ Fehler bei Git oder Update:", e)

conn_dev.close()
conn_prod.close()
