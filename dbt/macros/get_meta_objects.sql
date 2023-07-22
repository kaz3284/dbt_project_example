{% macro get_meta_objects(node_unique_id, meta_key) %}

	{% if execute %}

        {% set meta_columns = [] %}
        {% set columns = graph.nodes[node_unique_id]['columns']  %}
        {% for column in columns if graph.nodes[node_unique_id]['columns'][column]['meta'][meta_key] | length > 0 %}
            {% set meta_dict = graph.nodes[node_unique_id]['columns'][column]['meta'] %}
            {% for key, value in meta_dict.items() if key == meta_key %}
                {% set meta_tuple = (column ,value ) %}
                {% do meta_columns.append(meta_tuple) %}
            {% endfor %}
        {% endfor %}

        {{ return(meta_columns) }}

    {% endif %}
{% endmacro %}
