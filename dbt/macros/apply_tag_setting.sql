{% macro apply_tag_setting(meta_key="tag") %}
{# models.yml、snapshots.ymlのmeta属性の内容で、該当オブジェクトのカラムにタグを設定する #}

    {% if execute %}

        {% set model_id = model.unique_id | string %}
        {% set relation_name = model.relation_name %}

        {# This dictionary stores a mapping between materializations in dbt and the objects they will generate in Snowflake  #}
        {% set materialization_map = {"table": "table", "view": "view", "incremental": "table", "snapshot": "table"} %}

        {# Append custom materializations to the list of standard materializations  #}
        {% do materialization_map.update(fromjson(var('custom_materializations_map', '{}'))) %}

        {% set materialization = materialization_map[model.config.get("materialized")] %}
        {% set meta_columns = get_meta_objects(model_id,meta_key) %}

        {%- for meta_tuple in meta_columns if meta_columns | length > 0 %}
            {% set column   = meta_tuple[0] %}
            {% set tag_settings  = meta_tuple[1] %}

            {%- for tag_setting in tag_settings if tag_settings | length > 0 %}
                {% set tag_type  = tag_setting['type'] %}
                {% set tag_name  = tag_setting['name'] %}
                {% set tag_value  = tag_setting['value'] %}

                {# マスキングポリシーの設定 #}
                {% if tag_type == 'masking_policy' %}
                    -- マスキングポリシーのタグをオブジェクトのカラムに割り当てる
                    alter {{ materialization }} {{ relation_name }} modify column {{ column }} set tag tags.{{ tag_name }} = '{{ tag_value }}';
                {% endif %}
            {% endfor %}
        {% endfor %}

    {% endif %}

{% endmacro %}
