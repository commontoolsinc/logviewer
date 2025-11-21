defmodule LogViewer.EntityExtractorTest do
  use ExUnit.Case, async: true

  alias LogViewer.EntityExtractor
  alias LogViewer.Timeline.LogEvent
  alias LogViewer.Parser.{ClientLogEntry, ServerLogEntry}

  describe "extract_entities/1" do
    test "extracts docIDs from text" do
      text = "Stored doc baedreic7dvjvssmh6b62azkrx6o4wmymbbwffgx3brpte2ykm3y6ukepzm"

      entities = EntityExtractor.extract_entities(text)

      assert length(entities.doc_ids) == 1
      assert "baedreic7dvjvssmh6b62azkrx6o4wmymbbwffgx3brpte2ykm3y6ukepzm" in entities.doc_ids
    end

    test "extracts charmIDs from text" do
      text = "Running charm baedreiabc123xyz456def789ghi012jkl345mno678pqr901stu234vwx567yzab"

      entities = EntityExtractor.extract_entities(text)

      assert length(entities.charm_ids) == 1
      assert "baedreiabc123xyz456def789ghi012jkl345mno678pqr901stu234vwx567yzab" in entities.charm_ids
    end

    test "extracts spaceIDs (DIDs) from text" do
      text = "Processing request for space did:key:z6MkhaXgBZDvotDkL5257faiztiGiC2QtKLGpbnnEGta2doK"

      entities = EntityExtractor.extract_entities(text)

      assert length(entities.space_ids) == 1
      assert "did:key:z6MkhaXgBZDvotDkL5257faiztiGiC2QtKLGpbnnEGta2doK" in entities.space_ids
    end

    test "returns empty lists when no entities found" do
      text = "Just a regular log message with no IDs"

      entities = EntityExtractor.extract_entities(text)

      assert entities.doc_ids == []
      assert entities.charm_ids == []
      assert entities.space_ids == []
    end

    test "handles multiple entities of same type" do
      text = "Copied doc baedreic7dvjvssmh6b62azkrx6o4wmymbbwffgx3brpte2ykm3y6ukepzm to baedreiabc123xyz456def789ghi012jkl345mno678pqr901stu234vwx567yzab"

      entities = EntityExtractor.extract_entities(text)

      # Both are docIDs (start with baedrei)
      assert length(entities.doc_ids) == 2
    end

    test "deduplicates repeated entity IDs" do
      text = "Processing baedreic7dvjvssmh6b62azkrx6o4wmymbbwffgx3brpte2ykm3y6ukepzm and baedreic7dvjvssmh6b62azkrx6o4wmymbbwffgx3brpte2ykm3y6ukepzm again"

      entities = EntityExtractor.extract_entities(text)

      assert length(entities.doc_ids) == 1
    end

    test "extracts mixed entity types from same text" do
      text = "Stored doc baedreic7dvjvssmh6b62azkrx6o4wmymbbwffgx3brpte2ykm3y6ukepzm in space did:key:z6MkhaXgBZDvotDkL5257faiztiGiC2QtKLGpbnnEGta2doK"

      entities = EntityExtractor.extract_entities(text)

      assert length(entities.doc_ids) == 1
      assert length(entities.space_ids) == 1
      assert entities.charm_ids == []
    end
  end

  describe "build_entity_index/1" do
    test "builds index from timeline events" do
      events = [
        %LogEvent{
          timestamp: 1_732_204_800_100,
          level: "info",
          module: "memory",
          message: "Stored doc baedreic7dvjvssmh6b62azkrx6o4wmymbbwffgx3brpte2ykm3y6ukepzm",
          source: :client,
          raw_entry: %ClientLogEntry{
            timestamp: 1_732_204_800_100,
            level: "info",
            module: "memory",
            key: "storage",
            messages: []
          }
        },
        %LogEvent{
          timestamp: 1_732_204_800_500,
          level: "ERROR",
          module: "memory",
          message: "Failed to read doc baedreic7dvjvssmh6b62azkrx6o4wmymbbwffgx3brpte2ykm3y6ukepzm",
          source: :server,
          raw_entry: %ServerLogEntry{
            timestamp: 1_732_204_800_500,
            level: "ERROR",
            module: "memory",
            message: "Failed"
          }
        }
      ]

      index = EntityExtractor.build_entity_index(events)

      doc_id = "baedreic7dvjvssmh6b62azkrx6o4wmymbbwffgx3brpte2ykm3y6ukepzm"
      entity_info = index.entities[doc_id]

      assert entity_info != nil
      assert entity_info.id == doc_id
      assert entity_info.type == :doc_id
      assert entity_info.first_seen == 1_732_204_800_100
      assert entity_info.last_seen == 1_732_204_800_500
      assert entity_info.event_count == 2
      assert length(entity_info.events) == 2
    end

    test "groups entities by type" do
      events = [
        %LogEvent{
          timestamp: 1_732_204_800_100,
          level: "info",
          module: "memory",
          message: "Stored doc baedreic7dvjvssmh6b62azkrx6o4wmymbbwffgx3brpte2ykm3y6ukepzm",
          source: :client,
          raw_entry: %ClientLogEntry{
            timestamp: 1_732_204_800_100,
            level: "info",
            module: "memory",
            key: "storage",
            messages: []
          }
        },
        %LogEvent{
          timestamp: 1_732_204_800_200,
          level: "info",
          module: "runner",
          message: "Running charm baedreiabc123xyz456def789ghi012jkl345mno678pqr901stu234vwx567yzab",
          source: :client,
          raw_entry: %ClientLogEntry{
            timestamp: 1_732_204_800_200,
            level: "info",
            module: "runner",
            key: "execution",
            messages: []
          }
        },
        %LogEvent{
          timestamp: 1_732_204_800_300,
          level: "info",
          module: "toolshed",
          message: "Processing space did:key:z6MkhaXgBZDvotDkL5257faiztiGiC2QtKLGpbnnEGta2doK",
          source: :server,
          raw_entry: %ServerLogEntry{
            timestamp: 1_732_204_800_300,
            level: "INFO",
            module: "toolshed",
            message: "Processing"
          }
        }
      ]

      index = EntityExtractor.build_entity_index(events)

      assert length(index.by_type.doc_ids) == 1
      assert length(index.by_type.charm_ids) == 1
      assert length(index.by_type.space_ids) == 1
    end

    test "handles events with no entities" do
      events = [
        %LogEvent{
          timestamp: 1_732_204_800_100,
          level: "info",
          module: "test",
          message: "No entities here",
          source: :client,
          raw_entry: %ClientLogEntry{
            timestamp: 1_732_204_800_100,
            level: "info",
            module: "test",
            key: "test",
            messages: []
          }
        }
      ]

      index = EntityExtractor.build_entity_index(events)

      assert index.entities == %{}
      assert index.by_type.doc_ids == []
      assert index.by_type.charm_ids == []
      assert index.by_type.space_ids == []
    end

    test "handles empty timeline" do
      index = EntityExtractor.build_entity_index([])

      assert index.entities == %{}
      assert index.by_type.doc_ids == []
      assert index.by_type.charm_ids == []
      assert index.by_type.space_ids == []
    end
  end
end
